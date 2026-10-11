import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:classkhata/core/constants/app_constants.dart';
import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/core/security/password_hasher.dart';
import 'package:classkhata/features/auth/data/datasources/auth_dao.dart';
import 'package:classkhata/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:classkhata/features/auth/domain/usecases/login_usecase.dart';

void main() {
  group('Auth, Password Hashing & Lockout Security', () {
    test('PasswordHasher initializes and hashes with Argon2id', () async {
      await PasswordHasher.instance.initialize();
      final hashResult = await PasswordHasher.instance.hashPassword('SuperSecret123');
      expect(hashResult.isSuccess, isTrue);

      final hash = hashResult.valueOrThrow;
      expect(hash, contains('argon2'));

      final verifyOk = await PasswordHasher.instance.verifyPassword('SuperSecret123', hash);
      expect(verifyOk.isSuccess, isTrue);
      expect(verifyOk.valueOrThrow, isTrue);

      final verifyFail = await PasswordHasher.instance.verifyPassword('WrongPassword', hash);
      expect(verifyFail.isSuccess, isTrue);
      expect(verifyFail.valueOrThrow, isFalse);
    });

    test('Login locks out after 5 consecutive failed attempts for 15 minutes', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await PasswordHasher.instance.initialize();
      final hashResult = await PasswordHasher.instance.hashPassword('CorrectPass123');
      final hash = hashResult.valueOrThrow;

      final dao = AuthDao(db);
      final repo = AuthRepositoryImpl(dao);
      final loginUseCase = LoginUseCase(repo);

      // Create a test user
      await dao.createUser(
        UsersTableCompanion.insert(
          name: 'Accountant User',
          email: 'accountant@classkhata.com',
          passwordHash: hash,
          role: 'accountant',
        ),
      );

      // Attempts 1 to 4 should fail but not lock
      for (int i = 1; i <= 4; i++) {
        final res = await loginUseCase(
          email: 'accountant@classkhata.com',
          password: 'WrongPassword',
        );
        expect(res.isFailure, isTrue);
        final lockout = await repo.getLockoutStatus('accountant@classkhata.com');
        expect(lockout.valueOrThrow.isLocked, isFalse);
        expect(lockout.valueOrThrow.failedAttempts, equals(i));
      }

      // 5th failed attempt triggers lockout
      final res5 = await loginUseCase(
        email: 'accountant@classkhata.com',
        password: 'WrongPassword',
      );
      expect(res5.isFailure, isTrue);

      final lockout = await repo.getLockoutStatus('accountant@classkhata.com');
      expect(lockout.valueOrThrow.isLocked, isTrue);
      expect(lockout.valueOrThrow.failedAttempts, equals(AppConstants.maxLoginAttempts));
      expect(lockout.valueOrThrow.minutesRemaining, greaterThan(0));

      // Attempting to login even with correct password while locked must fail
      final lockedAttempt = await loginUseCase(
        email: 'accountant@classkhata.com',
        password: 'CorrectPass123',
      );
      expect(lockedAttempt.isFailure, isTrue);
      expect(
        lockedAttempt.fold(onSuccess: (_) => '', onFailure: (f) => f.message),
        contains('locked'),
      );
    });

    test('Successful login clears failed attempts and updates lastLoginAt', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await PasswordHasher.instance.initialize();
      final hashResult = await PasswordHasher.instance.hashPassword('MyPass123');
      final hash = hashResult.valueOrThrow;

      final dao = AuthDao(db);
      final repo = AuthRepositoryImpl(dao);
      final loginUseCase = LoginUseCase(repo);

      await dao.createUser(
        UsersTableCompanion.insert(
          name: 'Teacher User',
          email: 'teacher@classkhata.com',
          passwordHash: hash,
          role: 'teacher',
        ),
      );

      // 2 failed attempts
      await loginUseCase(email: 'teacher@classkhata.com', password: 'bad');
      await loginUseCase(email: 'teacher@classkhata.com', password: 'bad');

      final lockoutBefore = await repo.getLockoutStatus('teacher@classkhata.com');
      expect(lockoutBefore.valueOrThrow.failedAttempts, equals(2));

      // Successful login
      final successRes = await loginUseCase(email: 'teacher@classkhata.com', password: 'MyPass123');
      expect(successRes.isSuccess, isTrue);

      final user = successRes.valueOrThrow;
      expect(user.email, equals('teacher@classkhata.com'));
      expect(user.role.name, equals('teacher'));

      final lockoutAfter = await repo.getLockoutStatus('teacher@classkhata.com');
      expect(lockoutAfter.valueOrThrow.failedAttempts, equals(0));
      expect(lockoutAfter.valueOrThrow.isLocked, isFalse);
    });

    test('Forced password change flag is preserved on first login', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await PasswordHasher.instance.initialize();
      final hashResult = await PasswordHasher.instance.hashPassword('TempPass123');
      final hash = hashResult.valueOrThrow;

      final dao = AuthDao(db);
      final repo = AuthRepositoryImpl(dao);
      final loginUseCase = LoginUseCase(repo);

      await dao.createUser(
        UsersTableCompanion.insert(
          name: 'New Admin',
          email: 'admin@classkhata.com',
          passwordHash: hash,
          role: 'admin',
          mustChangePassword: const Value(true),
        ),
      );

      final res = await loginUseCase(email: 'admin@classkhata.com', password: 'TempPass123');
      expect(res.isSuccess, isTrue);
      expect(res.valueOrThrow.mustChangePassword, isTrue);
    });
  });
}
