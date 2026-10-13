/// Licensing repository implementation with offline RSA-2048 verification,
/// dual-storage tamper resistance, and clock-rollback detection.
library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../domain/entities/license_entities.dart';
import '../domain/repositories/licensing_repository.dart';
import 'hardware_identity.dart';
import 'licensing_public_key.dart';

class LicensingRepositoryImpl implements LicensingRepository {

  LicensingRepositoryImpl(
    this._db, {
    String? mockMachineId,
    Directory? overrideStorageDir,
  })  : _mockMachineId = mockMachineId,
        _overrideStorageDir = overrideStorageDir;
  final AppDatabase _db;
  final String? _mockMachineId;
  final Directory? _overrideStorageDir;

  static const String _trialSalt = 'CK_TRIAL_SECURITY_SALT_2026';

  String get machineId => HardwareIdentity.getMachineId(mockSeed: _mockMachineId);

  @override
  Future<Result<LicenseInfo>> getLicenseInfo({DateTime? overrideNow}) async {
    try {
      final now = overrideNow ?? DateTime.now();
      final currentMid = machineId;

      // 1. Fetch license state from database
      final stateRow = await (_db.select(_db.licenseStateTable)..limit(1)).getSingleOrNull();

      if (stateRow == null) {
        // Initialize 7-day trial on first run
        return await _initializeTrial(now, currentMid);
      }

      // 2. Check if already activated with valid lifetime license
      if (stateRow.status == 'active' && stateRow.licenseKey != null) {
        final verifyRes = _verifySignedToken(stateRow.licenseKey!, currentMid);
        if (verifyRes.isSuccess) {
          final payload = verifyRes.valueOrThrow;
          return Success(
            LicenseInfo(
              status: LicenseStatus.active,
              machineId: currentMid,
              trialStartedAt: stateRow.trialStartedAt ?? now,
              daysRemaining: 9999,
              academyName: payload['academyName'] as String?,
              licenseKey: stateRow.licenseKey,
              activatedAt: stateRow.activatedAt,
            ),
          );
        } else {
          // Token tampered or invalidated
          return Success(
            LicenseInfo(
              status: LicenseStatus.tampered,
              machineId: currentMid,
              trialStartedAt: stateRow.trialStartedAt ?? now,
              daysRemaining: 0,
              alertMessage: 'Stored license key is invalid or tampered.',
            ),
          );
        }
      }

      // 3. Clock-Rollback Detection Check
      final clockCheck = await _checkClockRollback(now);
      if (!clockCheck) {
        await AppLogger.instance.warning('System clock rollback detected! Licensing locked to read-only.');
        return Success(
          LicenseInfo(
            status: LicenseStatus.clockRollbackDetected,
            machineId: currentMid,
            trialStartedAt: stateRow.trialStartedAt ?? now,
            daysRemaining: 0,
            alertMessage: 'System clock rollback detected. Financial entry creation is suspended.',
          ),
        );
      }

      // 4. Verify trial integrity against dual anchor
      final trialStart = stateRow.trialStartedAt ?? now;
      final isTrialIntact = await _verifyTrialIntegrity(trialStart, currentMid);
      if (!isTrialIntact) {
        return Success(
          LicenseInfo(
            status: LicenseStatus.tampered,
            machineId: currentMid,
            trialStartedAt: trialStart,
            daysRemaining: 0,
            alertMessage: 'Trial record tamper detected across system storage.',
          ),
        );
      }

      // 5. Compute trial days remaining
      final difference = now.difference(trialStart);
      final daysElapsed = difference.inDays;

      if (daysElapsed >= 7 || difference.isNegative) {
        return Success(
          LicenseInfo(
            status: LicenseStatus.expired,
            machineId: currentMid,
            trialStartedAt: trialStart,
            daysRemaining: 0,
            alertMessage: '7-Day free trial has expired. Activate a license to create new entries.',
          ),
        );
      }

      final daysRemaining = 7 - daysElapsed;
      return Success(
        LicenseInfo(
          status: LicenseStatus.trial,
          machineId: currentMid,
          trialStartedAt: trialStart,
          daysRemaining: daysRemaining > 0 ? daysRemaining : 1,
        ),
      );
    } catch (e, st) {
      await AppLogger.instance.error('getLicenseInfo failed', error: e, stack: st);
      return Failure(DatabaseFailure('Licensing evaluation failed: $e'));
    }
  }

  @override
  Future<Result<LicenseInfo>> activateLicense(String licenseKeyToken) async {
    try {
      final currentMid = machineId;
      final cleanToken = licenseKeyToken.trim();

      // 1. Verify cryptographic token offline
      final verifyRes = _verifySignedToken(cleanToken, currentMid);
      if (verifyRes.isFailure) {
        return Failure(verifyRes.fold(onSuccess: (_) => const ValidationFailure(''), onFailure: (f) => f));
      }

      final payload = verifyRes.valueOrThrow;
      final now = DateTime.now();

      // 2. Persist activated state in database
      await _db.transaction(() async {
        final existing = await (_db.select(_db.licenseStateTable)..limit(1)).getSingleOrNull();
        if (existing == null) {
          await _db.into(_db.licenseStateTable).insert(
                LicenseStateTableCompanion.insert(
                  status: 'active',
                  machineId: Value(currentMid),
                  licenseKey: Value(cleanToken),
                  activatedAt: Value(now),
                  trialStartedAt: Value(now),
                ),
              );
        } else {
          await (_db.update(_db.licenseStateTable)..where((t) => t.id.equals(existing.id))).write(
            LicenseStateTableCompanion(
              status: const Value('active'),
              licenseKey: Value(cleanToken),
              activatedAt: Value(now),
              machineId: Value(currentMid),
              updatedAt: Value(now),
            ),
          );
        }

        // Store backup setting
        await _db.into(_db.settingsTable).insertOnConflictUpdate(
              SettingsTableCompanion.insert(
                key: 'license_status',
                value: 'active',
                updatedAt: Value(now),
              ),
            );
      });

      await AppLogger.instance.info('License successfully activated for machine $currentMid');

      return Success(
        LicenseInfo(
          status: LicenseStatus.active,
          machineId: currentMid,
          trialStartedAt: now,
          daysRemaining: 9999,
          academyName: payload['academyName'] as String?,
          licenseKey: cleanToken,
          activatedAt: now,
        ),
      );
    } catch (e, st) {
      await AppLogger.instance.error('activateLicense error', error: e, stack: st);
      return Failure(ValidationFailure('Activation failed: ${e.toString()}'));
    }
  }

  @override
  Future<Result<bool>> canPerformFinancialWrites() async {
    final infoRes = await getLicenseInfo();
    return infoRes.fold(
      onSuccess: (info) => Success(info.canPerformFinancialWrites),
      onFailure: (f) => Failure(f),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers & Tamper Checks
  // ---------------------------------------------------------------------------

  Future<Result<LicenseInfo>> _initializeTrial(DateTime now, String currentMid) async {
    final signature = _computeTrialSignature(now, currentMid);

    await _db.transaction(() async {
      await _db.into(_db.licenseStateTable).insert(
            LicenseStateTableCompanion.insert(
              status: 'trial',
              trialStartedAt: Value(now),
              machineId: Value(currentMid),
            ),
          );

      await _db.into(_db.settingsTable).insertOnConflictUpdate(
            SettingsTableCompanion.insert(
              key: 'trial_signature',
              value: signature,
              updatedAt: Value(now),
            ),
          );

      await _db.into(_db.settingsTable).insertOnConflictUpdate(
            SettingsTableCompanion.insert(
              key: 'last_seen_epoch',
              value: now.millisecondsSinceEpoch.toString(),
              updatedAt: Value(now),
            ),
          );
    });

    // Secondary location: hidden anchor file
    await _writeSecondaryAnchor(now, signature);

    return Success(
      LicenseInfo(
        status: LicenseStatus.trial,
        machineId: currentMid,
        trialStartedAt: now,
        daysRemaining: 7,
      ),
    );
  }

  String _computeTrialSignature(DateTime dt, String mid) {
    final epochSeconds = dt.millisecondsSinceEpoch ~/ 1000;
    final raw = '$epochSeconds|$mid|$_trialSalt';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<bool> _verifyTrialIntegrity(DateTime trialStart, String currentMid) async {
    final expectedSig = _computeTrialSignature(trialStart, currentMid);

    // 1. Check primary DB settings signature
    final sigRow = await (_db.select(_db.settingsTable)..where((t) => t.key.equals('trial_signature')))
        .getSingleOrNull();
    if (sigRow == null || sigRow.value != expectedSig) {
      return false;
    }

    // 2. Check secondary storage anchor
    final secondary = await _readSecondaryAnchor();
    if (secondary != null) {
      if (secondary['signature'] != expectedSig) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _checkClockRollback(DateTime now) async {
    final lastRow = await (_db.select(_db.settingsTable)..where((t) => t.key.equals('last_seen_epoch')))
        .getSingleOrNull();

    final nowEpoch = now.millisecondsSinceEpoch;

    if (lastRow != null) {
      final lastEpoch = int.tryParse(lastRow.value) ?? 0;
      // Allow up to 2 minutes clock jitter
      if (nowEpoch < (lastEpoch - 120000)) {
        return false; // Clock was rolled back!
      }
    }

    // Update last seen epoch
    await _db.into(_db.settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion.insert(
            key: 'last_seen_epoch',
            value: nowEpoch.toString(),
            updatedAt: Value(now),
          ),
        );

    return true;
  }

  /// Verifies an RSA-2048 signed token offline with ONLY the public key.
  Result<Map<String, dynamic>> _verifySignedToken(String token, String currentMid) {
    final parts = token.split('.');
    if (parts.length != 2) {
      return const Failure(ValidationFailure('Invalid license format. Must be a signed token.'));
    }

    try {
      final payloadB64 = parts[0];
      final signatureB64 = parts[1];

      final payloadBytes = base64Url.decode(base64.normalize(payloadB64));
      final signatureBytes = base64Url.decode(base64.normalize(signatureB64));

      // 1. Verify signature with embedded Public Key
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(LicensingPublicKey.key));

      final isValid = verifier.verifySignature(
        Uint8List.fromList(payloadBytes),
        RSASignature(Uint8List.fromList(signatureBytes)),
      );

      if (!isValid) {
        return const Failure(ValidationFailure('Cryptographic verification failed: Invalid signature.'));
      }

      // 2. Decode and check payload contents
      final payloadMap = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;

      if (payloadMap['app'] != 'ClassKhata') {
        return const Failure(ValidationFailure('License token is for an incompatible application.'));
      }

      final licensedMid = (payloadMap['machineId'] as String?)?.toUpperCase();
      if (licensedMid != currentMid.toUpperCase()) {
        return Failure(
          ValidationFailure(
            'License is locked to a different computer (Registered: $licensedMid, This PC: $currentMid).',
          ),
        );
      }

      return Success(payloadMap);
    } catch (e) {
      return Failure(ValidationFailure('Malformed license key token: $e'));
    }
  }

  // Secondary anchor storage file (outside database)
  Future<File> _getAnchorFile() async {
    final dir = _overrideStorageDir ?? await getApplicationSupportDirectory();
    return File(p.join(dir.path, '.ck_security_anchor.json'));
  }

  Future<void> _writeSecondaryAnchor(DateTime dt, String sig) async {
    try {
      final file = await _getAnchorFile();
      final content = jsonEncode({
        'trialStart': dt.toIso8601String(),
        'signature': sig,
        'anchorDate': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(content);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSecondaryAnchor() async {
    try {
      final file = await _getAnchorFile();
      if (!file.existsSync()) return null;
      final text = await file.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
