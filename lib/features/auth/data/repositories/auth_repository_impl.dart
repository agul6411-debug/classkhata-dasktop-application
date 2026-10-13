/// Auth repository implementation.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/permission_service.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_dao.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDao _dao;

  const AuthRepositoryImpl(this._dao);

  @override
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userRow = await _dao.getUserByEmail(email);
      if (userRow == null) {
        // Don't reveal whether the user exists
        return const Failure(AuthFailure('Invalid email or password.'));
      }

      if (!userRow.isActive) {
        return const Failure(AuthFailure('This account has been deactivated.'));
      }

      // Check if still locked
      if (userRow.lockedUntil != null &&
          userRow.lockedUntil!.isAfter(DateTime.now())) {
        final mins = userRow.lockedUntil!.difference(DateTime.now()).inMinutes + 1;
        return Failure(AuthFailure('Account locked. Try again in $mins minutes.'));
      }

      // Verify password
      final verifyResult = await PasswordHasher.instance.verifyPassword(
        password,
        userRow.passwordHash,
      );
      if (verifyResult.isFailure) {
        return Failure(verifyResult.fold(
          onSuccess: (_) => const UnexpectedFailure(''),
          onFailure: (f) => f,
        ));
      }

      final passwordOk = verifyResult.valueOrThrow;
      if (!passwordOk) {
        final newAttempts = userRow.failedLoginAttempts + 1;
        DateTime? lockUntil;
        if (newAttempts >= AppConstants.maxLoginAttempts) {
          lockUntil = DateTime.now().add(AppConstants.lockoutDuration);
        }
        await _dao.recordFailedLogin(
          userId: userRow.id,
          newAttemptCount: newAttempts,
          lockUntil: lockUntil,
        );
        return const Failure(AuthFailure('Invalid email or password.'));
      }

      // Success
      await _dao.recordSuccessfulLogin(userRow.id);

      final role = _parseRole(userRow.role);
      final user = AuthUser(
        id: userRow.id,
        name: userRow.name,
        email: userRow.email,
        role: role,
        permissions: permissionsForRole(role),
        mustChangePassword: userRow.mustChangePassword,
      );
      return Success(user);
    } catch (e, st) {
      await AppLogger.instance.error('Login error', error: e, stack: st);
      return Failure(
        UnexpectedFailure('An unexpected error occurred.', technicalDetail: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<LockoutStatus>> getLockoutStatus(String email) async {
    try {
      final userRow = await _dao.getUserByEmail(email);
      if (userRow == null) {
        return const Success(LockoutStatus(isLocked: false, failedAttempts: 0));
      }
      final isLocked = userRow.lockedUntil != null &&
          userRow.lockedUntil!.isAfter(DateTime.now());
      return Success(
        LockoutStatus(
          isLocked: isLocked,
          lockedUntil: userRow.lockedUntil,
          failedAttempts: userRow.failedLoginAttempts,
        ),
      );
    } catch (e, st) {
      await AppLogger.instance.error('getLockoutStatus error', error: e, stack: st);
      return Failure(UnexpectedFailure('Lockout check failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (newPassword.length < AppConstants.minPasswordLength) {
        return Failure(
          ValidationFailure(
            'Password must be at least ${AppConstants.minPasswordLength} characters.',
          ),
        );
      }
      final userRow = await _dao.getUserById(userId);
      if (userRow == null) {
        return const Failure(AuthFailure('User not found.'));
      }
      final verify = await PasswordHasher.instance.verifyPassword(
        currentPassword,
        userRow.passwordHash,
      );
      if (verify.isFailure || !verify.valueOrThrow) {
        return const Failure(AuthFailure('Current password is incorrect.'));
      }
      final hashResult = await PasswordHasher.instance.hashPassword(newPassword);
      if (hashResult.isFailure) return Failure(hashResult.fold(
        onSuccess: (_) => const UnexpectedFailure(''),
        onFailure: (f) => f,
      ));
      await _dao.updateUser(
        userId,
        UsersTableCompanion(
          passwordHash: Value(hashResult.valueOrThrow),
          mustChangePassword: const Value(false),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('changePassword error', error: e, stack: st);
      return Failure(UnexpectedFailure('Password change failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<bool>> verifyRecoveryKey({
    required String email,
    required String recoveryKey,
  }) async {
    try {
      final userRow = await _dao.getUserByEmail(email);
      if (userRow == null) return const Success(false);
      final keyRow = await _dao.getActiveRecoveryKey(userRow.id);
      if (keyRow == null) return const Success(false);
      final hash = sha256.convert(utf8.encode(recoveryKey)).toString();
      return Success(hash == keyRow.keyHash);
    } catch (e, st) {
      await AppLogger.instance.error('verifyRecoveryKey error', error: e, stack: st);
      return Failure(UnexpectedFailure('Recovery key verification failed.'));
    }
  }

  @override
  Future<Result<void>> resetPasswordWithRecoveryKey({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    try {
      final verifyResult = await verifyRecoveryKey(
        email: email,
        recoveryKey: recoveryKey,
      );
      if (verifyResult.isFailure || !verifyResult.valueOrThrow) {
        return const Failure(AuthFailure('Invalid recovery key.'));
      }
      final userRow = await _dao.getUserByEmail(email);
      if (userRow == null) return const Failure(AuthFailure('User not found.'));

      final hashResult = await PasswordHasher.instance.hashPassword(newPassword);
      if (hashResult.isFailure) return Failure(hashResult.fold(
        onSuccess: (_) => const UnexpectedFailure(''),
        onFailure: (f) => f,
      ));
      await _dao.updateUser(
        userRow.id,
        UsersTableCompanion(
          passwordHash: Value(hashResult.valueOrThrow),
          mustChangePassword: const Value(false),
          failedLoginAttempts: const Value(0),
          lockedUntil: const Value(null),
        ),
      );
      // Mark recovery key as used
      final keyRow = await _dao.getActiveRecoveryKey(userRow.id);
      if (keyRow != null) await _dao.markRecoveryKeyUsed(keyRow.id);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('resetPasswordWithRecoveryKey error', error: e, stack: st);
      return Failure(UnexpectedFailure('Password reset failed.', technicalDetail: e.toString()));
    }
  }

  AppRole _parseRole(String role) {
    return AppRole.values.firstWhere(
      (r) => r.name == role,
      orElse: () => AppRole.viewer,
    );
  }
}

// Drift's Value<T> is used above for companion fields (imported via core_tables.dart)
