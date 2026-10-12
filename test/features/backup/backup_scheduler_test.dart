import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:classkhata/features/backup/domain/usecases/backup_scheduler_service.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late BackupRepositoryImpl backupRepo;
  late BackupSchedulerService scheduler;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('ck_backup_sched_test_');

    // Create a mock active db file
    final mockDbFile = File('${tempDir.path}${Platform.pathSeparator}classkhata.db');
    await mockDbFile.writeAsString('SQLITE_CIPHER_MOCK_CONTENT');

    backupRepo = BackupRepositoryImpl(db, overrideAppDir: tempDir);
    scheduler = BackupSchedulerService(db, backupRepo, overrideTempDir: tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Backup Scheduler, Retention & Test Restore', () {
    test('checkAndRunDailyBackup triggers backup on first run when due', () async {
      final res = await scheduler.checkAndRunDailyBackup(createdBy: 1);
      expect(res.isSuccess, isTrue);

      final meta = res.valueOrThrow;
      expect(meta, isNotNull);
      expect(meta!.type, equals('auto'));

      // Check record in database
      final backups = (await backupRepo.listBackups()).valueOrThrow;
      expect(backups.length, equals(1));
    });

    test('checkAndRunDailyBackup skips execution if backup was already run within 24 hours', () async {
      // First execution
      final first = await scheduler.checkAndRunDailyBackup(createdBy: 1);
      expect(first.valueOrThrow, isNotNull);

      // Second immediate execution within 24 hours
      final second = await scheduler.checkAndRunDailyBackup(createdBy: 1);
      expect(second.isSuccess, isTrue);
      expect(second.valueOrThrow, isNull); // Skipped

      final backups = (await backupRepo.listBackups()).valueOrThrow;
      expect(backups.length, equals(1));
    });

    test('pruneBackupsRetention prunes old backups keeping last N', () async {
      // Create 5 backups manually
      for (int i = 0; i < 5; i++) {
        await backupRepo.createBackup(type: 'auto', createdBy: 1);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      var list = (await backupRepo.listBackups()).valueOrThrow;
      expect(list.length, equals(5));

      // Prune to keep last 3
      final pruned = await scheduler.pruneBackupsRetention(overrideRetentionCount: 3);
      expect(pruned, equals(2));

      list = (await backupRepo.listBackups()).valueOrThrow;
      expect(list.length, equals(3));
    });

    test('testRestoreBackup validates backup checksum and sandbox without touching active DB', () async {
      final backupRes = await backupRepo.createBackup(type: 'manual', createdBy: 1);
      final meta = backupRes.valueOrThrow;

      final testRes = await scheduler.testRestoreBackup(meta.id);
      expect(testRes.isSuccess, isTrue);

      final result = testRes.valueOrThrow;
      expect(result.isSuccessful, isTrue);
      expect(result.checksum, equals(meta.checksum));
      expect(result.backupSize, greaterThan(0));
    });
  });
}
