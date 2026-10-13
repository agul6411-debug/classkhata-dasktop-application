import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/licensing/data/licensing_repository_impl.dart';
import 'package:classkhata/features/licensing/domain/entities/license_entities.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools/generate_license.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  const mockMid = 'CK-1111-2222-3333';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('ck_license_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Offline Cryptographic Licensing & Verification', () {
    test('Initial run activates 7-day trial mode with intact dual anchor', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      final result = await repo.getLicenseInfo();
      expect(result.isSuccess, isTrue);

      final info = result.valueOrThrow;
      expect(info.status, equals(LicenseStatus.trial));
      expect(info.daysRemaining, equals(7));
      expect(info.isReadonly, isFalse);
      expect(info.canPerformFinancialWrites, isTrue);
    });

    test('Computes remaining trial days accurately over time', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      final now = DateTime.now();
      // First run initializes trial
      await repo.getLicenseInfo(overrideNow: now);

      // Check 3 days later
      final day3 = now.add(const Duration(days: 3));
      final info3 = (await repo.getLicenseInfo(overrideNow: day3)).valueOrThrow;
      expect(info3.status, equals(LicenseStatus.trial));
      expect(info3.daysRemaining, equals(4));
      expect(info3.canPerformFinancialWrites, isTrue);

      // Check 7 days later (expired)
      final day7 = now.add(const Duration(days: 7, hours: 1));
      final info7 = (await repo.getLicenseInfo(overrideNow: day7)).valueOrThrow;
      expect(info7.status, equals(LicenseStatus.expired));
      expect(info7.daysRemaining, equals(0));
      expect(info7.isReadonly, isTrue);
      expect(info7.canPerformFinancialWrites, isFalse);
    });

    test('Detects system clock rollback and locks to read-only mode', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      final now = DateTime.now();
      // Initialize at current time
      await repo.getLicenseInfo(overrideNow: now);

      // Advance clock by 2 days
      await repo.getLicenseInfo(overrideNow: now.add(const Duration(days: 2)));

      // Roll back clock backwards by 5 days
      final rolledBack = now.subtract(const Duration(days: 3));
      final result = await repo.getLicenseInfo(overrideNow: rolledBack);
      expect(result.isSuccess, isTrue);

      final info = result.valueOrThrow;
      expect(info.status, equals(LicenseStatus.clockRollbackDetected));
      expect(info.isReadonly, isTrue);
      expect(info.canPerformFinancialWrites, isFalse);
    });

    test('Validates and activates valid RSA lifetime license token for this machine', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      // Generate genuine signed license token using offline tool
      final token = generateSignedLicenseKey(
        machineId: repo.machineId,
        academyName: 'Army Public School',
      );

      final activateRes = await repo.activateLicense(token);
      expect(activateRes.isSuccess, isTrue);

      final info = activateRes.valueOrThrow;
      expect(info.status, equals(LicenseStatus.active));
      expect(info.isActivated, isTrue);
      expect(info.academyName, equals('Army Public School'));
      expect(info.canPerformFinancialWrites, isTrue);

      // Subsequent status check returns active
      final verifyRes = await repo.getLicenseInfo();
      expect(verifyRes.valueOrThrow.status, equals(LicenseStatus.active));
    });

    test('Rejects valid license token generated for a different machine ID', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      // Token generated for a different PC
      const differentMid = 'CK-9999-8888-7777';
      final foreignToken = generateSignedLicenseKey(
        machineId: differentMid,
        academyName: 'Other Academy',
      );

      final res = await repo.activateLicense(foreignToken);
      expect(res.isFailure, isTrue);
      final msg = res.fold(onSuccess: (_) => '', onFailure: (f) => f.message);
      expect(msg, contains('different computer'));
    });

    test('Rejects tampered license token with modified signature or payload', () async {
      final repo = LicensingRepositoryImpl(
        db,
        mockMachineId: mockMid,
        overrideStorageDir: tempDir,
      );

      final validToken = generateSignedLicenseKey(
        machineId: repo.machineId,
        academyName: 'Beaconhouse School System',
      );

      // Tamper signature by replacing with invalid RSA signature bytes
      final parts = validToken.split('.');
      final tamperedSig = base64Url.encode(Uint8List(256));
      final tamperedToken = '${parts[0]}.$tamperedSig';

      final res = await repo.activateLicense(tamperedToken);
      expect(res.isFailure, isTrue);
      final msg = res.fold(onSuccess: (_) => '', onFailure: (f) => f.message);
      expect(msg, contains('Cryptographic verification failed'));
    });
  });
}
