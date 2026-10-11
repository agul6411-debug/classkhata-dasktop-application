import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/constants/app_constants.dart';
import 'package:classkhata/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Schema & Migration Framework', () {
    test('database reports expected schemaVersion', () {
      expect(db.schemaVersion, equals(AppConstants.dbSchemaVersion));
      expect(db.schemaVersion, equals(1));
    });

    test('onCreate seeds default application settings', () async {
      final settings = await db.select(db.settingsTable).get();
      final settingsMap = {for (final s in settings) s.key: s.value};

      expect(settingsMap['language'], equals('en'));
      expect(settingsMap['theme'], equals('light'));
      expect(settingsMap['auto_lock_enabled'], equals('true'));
      expect(settingsMap['auto_backup_enabled'], equals('true'));
    });

    test('core tables support inserts and queries without errors', () async {
      // 1. Academy Profile
      final academyId = await db.into(db.academyProfileTable).insert(
            AcademyProfileTableCompanion.insert(
              name: 'Al-Huda Academy',
              phone: const Value('03001234567'),
              tagline: const Value('Excellence in Education'),
              address: const Value('Main Campus, Lahore'),
            ),
          );
      expect(academyId, greaterThan(0));

      final academy = await (db.select(db.academyProfileTable)
            ..where((t) => t.id.equals(academyId)))
          .getSingle();
      expect(academy.name, equals('Al-Huda Academy'));

      // 2. Users Table
      final userId = await db.into(db.usersTable).insert(
            UsersTableCompanion.insert(
              name: 'Admin User',
              email: 'admin@classkhata.com',
              passwordHash: 'dummy_argon2_hash',
              role: 'admin',
            ),
          );
      expect(userId, greaterThan(0));

      // 3. Recovery Keys Table
      final recId = await db.into(db.recoveryKeysTable).insert(
            RecoveryKeysTableCompanion.insert(
              userId: userId,
              keyHash: 'dummy_recovery_hash',
            ),
          );
      expect(recId, greaterThan(0));

      // 4. Audit Log Table
      final auditId = await db.into(db.auditLogTable).insert(
            AuditLogTableCompanion.insert(
              action: 'academy.created',
              entityType: 'AcademyProfile',
              entityId: const Value('1'),
              userId: userId,
              previousHash: AppConstants.auditChainGenesisHash,
              entryHash: 'dummy_audit_hash_1',
            ),
          );
      expect(auditId, greaterThan(0));

      // 5. Backups Meta Table
      final backupId = await db.into(db.backupsMetaTable).insert(
            BackupsMetaTableCompanion.insert(
              filePath: 'C:/backups/snapshot_01.db',
              type: 'manual',
              sizeBytes: 10240,
              checksum: 'dummy_sha256_checksum',
            ),
          );
      expect(backupId, greaterThan(0));
    });
  });
}
