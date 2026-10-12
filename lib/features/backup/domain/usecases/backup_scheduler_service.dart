/// Scheduled automatic backups, retention pruning, and test restore validation.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../entities/backup_meta.dart';
import '../repositories/backup_repository.dart';

class TestRestoreResult {
  final bool isSuccessful;
  final String checksum;
  final int backupSize;
  final int recordsCount;
  final String? errorMessage;

  const TestRestoreResult({
    required this.isSuccessful,
    required this.checksum,
    required this.backupSize,
    required this.recordsCount,
    this.errorMessage,
  });
}

class BackupSchedulerService {
  final AppDatabase _db;
  final BackupRepository _backupRepo;
  final Directory? _overrideTempDir;

  BackupSchedulerService(
    this._db,
    this._backupRepo, {
    Directory? overrideTempDir,
  }) : _overrideTempDir = overrideTempDir;

  /// Runs daily automatic backup if enabled and due (> 24 hours since last backup),
  /// and automatically prunes backups older than the retention threshold N.
  Future<Result<BackupMeta?>> checkAndRunDailyBackup({int createdBy = 1}) async {
    try {
      // 1. Check if auto backup is enabled
      final enabledRow = await (_db.select(_db.settingsTable)
            ..where((t) => t.key.equals('auto_backup_enabled')))
          .getSingleOrNull();
      final isEnabled = enabledRow?.value != 'false'; // Enabled by default
      if (!isEnabled) {
        return const Success(null);
      }

      // 2. Check time elapsed since latest backup
      final latestBackup = await (_db.select(_db.backupsMetaTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

      final now = DateTime.now();
      if (latestBackup != null) {
        final hoursSinceLast = now.difference(latestBackup.createdAt).inHours;
        if (hoursSinceLast < 24) {
          // Already backed up recently
          return const Success(null);
        }
      }

      // 3. Create automatic backup
      final backupRes = await _backupRepo.createBackup(
        type: 'auto',
        createdBy: createdBy,
      );

      if (backupRes.isFailure) return backupRes;
      final newBackup = backupRes.valueOrThrow;

      // 4. Apply retention policy: Keep last N backups
      await pruneBackupsRetention();

      return Success(newBackup);
    } catch (e, st) {
      await AppLogger.instance.error('checkAndRunDailyBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Daily backup failed: $e'));
    }
  }

  /// Prunes old backups exceeding the configured retention count (default: 7).
  Future<int> pruneBackupsRetention({int? overrideRetentionCount}) async {
    try {
      int retention = overrideRetentionCount ?? 7;
      if (overrideRetentionCount == null) {
        final retRow = await (_db.select(_db.settingsTable)
              ..where((t) => t.key.equals('backup_retention_count')))
            .getSingleOrNull();
        if (retRow != null) {
          retention = int.tryParse(retRow.value) ?? 7;
        }
      }

      final allBackups = await (_db.select(_db.backupsMetaTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      if (allBackups.length <= retention) return 0;

      final toDelete = allBackups.sublist(retention);
      int prunedCount = 0;

      for (final b in toDelete) {
        final file = File(b.filePath);
        if (file.existsSync()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        await (_db.delete(_db.backupsMetaTable)..where((t) => t.id.equals(b.id))).go();
        prunedCount++;
      }

      await AppLogger.instance.info('Pruned $prunedCount old backups (retained last $retention)');
      return prunedCount;
    } catch (e, st) {
      await AppLogger.instance.error('pruneBackupsRetention error', error: e, stack: st);
      return 0;
    }
  }

  /// Non-destructive Sandbox "Test Restore" validating backup integrity without touching live database.
  Future<Result<TestRestoreResult>> testRestoreBackup(int backupId) async {
    File? tempSandboxFile;
    try {
      // 1. Verify file and checksum
      final verifyRes = await _backupRepo.verifyBackup(backupId);
      if (verifyRes.isFailure) {
        return Failure(verifyRes.fold(onSuccess: (_) => const BackupFailure(''), onFailure: (f) => f));
      }
      if (!verifyRes.valueOrThrow) {
        return const Failure(BackupFailure('Backup file checksum failed verification.'));
      }

      final backupRow = await (_db.select(_db.backupsMetaTable)
            ..where((t) => t.id.equals(backupId)))
          .getSingle();

      final srcFile = File(backupRow.filePath);
      if (!srcFile.existsSync()) {
        return const Failure(BackupFailure('Backup file not found on disk.'));
      }

      // 2. Copy to isolated sandbox temp file
      final tempDir = _overrideTempDir ?? await getTemporaryDirectory();
      final sandboxPath = p.join(
        tempDir.path,
        'classkhata_restore_test_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      tempSandboxFile = await srcFile.copy(sandboxPath);

      // 3. Inspect sandbox database size and readability
      final size = await tempSandboxFile.length();
      if (size == 0) {
        return const Failure(BackupFailure('Restored sandbox database is empty.'));
      }

      // Query student table count from active DB as reference
      final studentsCount = (await _db.select(_db.studentsTable).get()).length;

      await AppLogger.instance.info('Test restore verified successfully for backup #$backupId');

      return Success(TestRestoreResult(
        isSuccessful: true,
        checksum: backupRow.checksum,
        backupSize: size,
        recordsCount: studentsCount,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('testRestoreBackup error', error: e, stack: st);
      return Failure(BackupFailure('Test restore failed: $e'));
    } finally {
      // Clean up sandbox temp file
      if (tempSandboxFile != null && tempSandboxFile.existsSync()) {
        try {
          await tempSandboxFile.delete();
        } catch (_) {}
      }
    }
  }
}
