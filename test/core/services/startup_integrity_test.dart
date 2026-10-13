import 'dart:io';

import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/core/security/audit_chain.dart';
import 'package:classkhata/core/services/startup_integrity_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('ck_integrity_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Startup Integrity Checks & Plain-Language Warning Handling', () {
    test('Healthy system reports all green with zero warnings', () async {
      final service = StartupIntegrityService(db, tempDir);
      final result = await service.runStartupChecks();

      expect(result.isHealthy, isTrue);
      expect(result.dbHealthy, isTrue);
      expect(result.auditChainHealthy, isTrue);
      expect(result.backupFolderHealthy, isTrue);
      expect(result.userFriendlyMessage, isNull);
    });

    test('Detects tampered audit chain and surfaces non-technical security warning', () async {
      final now = DateTime.now();
      // 1. Insert a genuine genesis record
      final hash1 = computeAuditHash(
        action: 'fee.collected',
        entityType: 'FeePayment',
        entityId: '101',
        userId: 1,
        createdAt: now,
        details: '{"amount": 500000}',
        previousHash: 'GENESIS',
      );

      await db.into(db.auditLogTable).insert(
            AuditLogTableCompanion.insert(
              id: const Value(1),
              action: 'fee.collected',
              entityType: 'FeePayment',
              entityId: const Value('101'),
              userId: 1,
              previousHash: 'GENESIS',
              entryHash: hash1,
            ),
          );

      // 2. Insert a second tampered record with incorrect previousHash
      await db.into(db.auditLogTable).insert(
            AuditLogTableCompanion.insert(
              id: const Value(2),
              action: 'fee.collected',
              entityType: 'FeePayment',
              entityId: const Value('102'),
              userId: 1,
              previousHash: 'FAKE_PREV_HASH_TAMPERED',
              entryHash: 'FAKE_ENTRY_HASH',
            ),
          );

      final service = StartupIntegrityService(db, tempDir);
      final result = await service.runStartupChecks();

      expect(result.isHealthy, isFalse);
      expect(result.auditChainHealthy, isFalse);
      expect(result.userFriendlyMessage, isNotNull);
      expect(result.userFriendlyMessage, contains('Security Alert'));
      expect(result.userFriendlyMessage, contains('financial audit log'));
    });
  });
}
