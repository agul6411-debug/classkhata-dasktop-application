/// Setup repository implementation.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/password_hasher.dart';
import '../../domain/entities/setup_data.dart';
import '../../domain/repositories/setup_repository.dart';
import '../datasources/setup_dao.dart';

class SetupRepositoryImpl implements SetupRepository {

  const SetupRepositoryImpl(this._dao);
  final SetupDao _dao;

  @override
  Future<Result<bool>> isSetupComplete() async {
    try {
      final count = await _dao.getAcademyCount();
      return Success(count > 0);
    } catch (e, st) {
      await AppLogger.instance.error('isSetupComplete error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not check setup state.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<String>> runSetup(SetupData data) async {
    try {
      // Hash admin password
      final hashResult = await PasswordHasher.instance.hashPassword(data.adminPassword);
      if (hashResult.isFailure) {
        return Failure(hashResult.fold(
          onSuccess: (_) => const UnexpectedFailure(''),
          onFailure: (f) => f,
        ));
      }
      final passwordHash = hashResult.valueOrThrow;

      // Generate recovery key (32 random alphanumeric chars, grouped)
      final recoveryKey = _generateRecoveryKey();
      final recoveryKeyHash = sha256.convert(utf8.encode(recoveryKey)).toString();

      // All DB writes inside a single transaction
      await _dao.db.transaction(() async {
        // 1. Academy profile
        await _dao.insertAcademy(
          AcademyProfileTableCompanion.insert(
            name: data.academyName.trim(),
            tagline: Value(data.tagline?.trim()),
            phone: Value(data.phone?.trim()),
            address: Value(data.address?.trim()),
          ),
        );

        // 2. Admin user
        final userId = await _dao.insertUser(
          UsersTableCompanion.insert(
            name: data.adminName.trim(),
            email: data.adminEmail.trim().toLowerCase(),
            passwordHash: passwordHash,
            role: 'admin',
            mustChangePassword: const Value(false),
          ),
        );

        // 3. Recovery key (stored as hash only)
        await _dao.insertRecoveryKey(
          RecoveryKeysTableCompanion.insert(
            userId: userId,
            keyHash: recoveryKeyHash,
          ),
        );

        // 4. License state (trial)
        await _dao.insertLicenseState(
          LicenseStateTableCompanion.insert(
            status: 'trial',
            trialStartedAt: Value(DateTime.now()),
          ),
        );
      });

      await AppLogger.instance.info('Setup complete. Admin user created.');
      return Success(recoveryKey);
    } catch (e, st) {
      await AppLogger.instance.critical('runSetup failed', error: e, stack: st);
      return Failure(UnexpectedFailure('Setup failed. Please try again.', technicalDetail: e.toString()));
    }
  }

  /// Generates a human-readable recovery key like: ABCD-EFGH-1234-5678
  String _generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final groups = List.generate(4, (_) {
      return List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    });
    return groups.join('-');
  }
}
