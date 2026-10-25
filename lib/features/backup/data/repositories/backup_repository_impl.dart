/// Backup repository implementation.
///
/// Creates a file copy of the database (already encrypted by SQLCipher).
/// Computes a SHA-256 checksum and records it in the DB.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/backup_meta.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {

  const BackupRepositoryImpl(this._db, {Directory? overrideAppDir})
      : _overrideAppDir = overrideAppDir;
  final AppDatabase _db;
  final Directory? _overrideAppDir;

  @override
  Future<Result<BackupMeta>> createBackup({
    required String type,
    required int createdBy,
  }) async {
    try {
      try {
        await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (e) {
        await AppLogger.instance.warning('wal_checkpoint before createBackup: $e');
      }

      final srcFile = await _dbFile();
      if (!srcFile.existsSync()) {
        return const Failure(BackupFailure('Database file not found.'));
      }

      final backupDir = await _backupDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final destFile = File(p.join(backupDir.path, 'classkhata_$ts.db'));

      await srcFile.copy(destFile.path);

      final checksum = await _sha256File(destFile);
      final size = await destFile.length();

      final id = await _db.into(_db.backupsMetaTable).insert(
            BackupsMetaTableCompanion.insert(
              filePath: destFile.path,
              type: type,
              sizeBytes: size,
              checksum: checksum,
              createdBy: Value(createdBy),
            ),
          );

      await AppLogger.instance
          .info('Backup created: ${destFile.path} (${size ~/ 1024} KB)');

      return Success(BackupMeta(
        id: id,
        filePath: destFile.path,
        type: type,
        sizeBytes: size,
        checksum: checksum,
        isVerified: false,
        createdAt: DateTime.now(),
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Backup failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<BackupMeta>>> listBackups() async {
    try {
      final rows = await (_db.select(_db.backupsMetaTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      final list = rows.map((r) => BackupMeta(
            id: r.id,
            filePath: r.filePath,
            type: r.type,
            sizeBytes: r.sizeBytes,
            checksum: r.checksum,
            isVerified: r.isVerified,
            createdAt: r.createdAt,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('listBackups failed', error: e, stack: st);
      return Failure(BackupFailure('Could not list backups.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<bool>> verifyBackup(int backupId) async {
    try {
      final row = await (_db.select(_db.backupsMetaTable)
            ..where((b) => b.id.equals(backupId)))
          .getSingleOrNull();
      if (row == null) return const Failure(BackupFailure('Backup record not found.'));

      final file = File(row.filePath);
      if (!file.existsSync()) {
        return const Failure(BackupFailure('Backup file missing from disk.'));
      }

      final currentChecksum = await _sha256File(file);
      final ok = currentChecksum == row.checksum;

      await (_db.update(_db.backupsMetaTable)
            ..where((b) => b.id.equals(backupId)))
          .write(BackupsMetaTableCompanion(isVerified: Value(ok)));

      return Success(ok);
    } catch (e, st) {
      await AppLogger.instance.error('verifyBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Backup verification failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> restoreBackup(int backupId) async {
    try {
      // Verify first
      final verifyResult = await verifyBackup(backupId);
      if (verifyResult.isFailure) {
        return Failure(verifyResult.fold(
          onSuccess: (_) => const BackupFailure(''),
          onFailure: (f) => f,
        ));
      }
      if (!verifyResult.valueOrThrow) {
        return const Failure(BackupFailure('Backup checksum mismatch. Restore aborted.'));
      }

      final row = await (_db.select(_db.backupsMetaTable)
            ..where((b) => b.id.equals(backupId)))
          .getSingle();

      try {
        await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (_) {}

      final src = File(row.filePath);
      final dest = await _dbFile();

      await src.copy(dest.path);

      // Clean up WAL and SHM companion files so stale WAL transactions are not replayed
      final walFile = File('${dest.path}-wal');
      if (walFile.existsSync()) {
        try {
          await walFile.delete();
        } catch (_) {}
      }
      final shmFile = File('${dest.path}-shm');
      if (shmFile.existsSync()) {
        try {
          await shmFile.delete();
        } catch (_) {}
      }

      await AppLogger.instance.info('Backup restored from ${src.path}. Restart required.');
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('restoreBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Restore failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> restoreFromFile(File backupFile) async {
    try {
      if (!backupFile.existsSync()) {
        return const Failure(BackupFailure('Selected backup file does not exist on disk.'));
      }

      final fileSize = await backupFile.length();
      if (fileSize < 16) {
        return const Failure(BackupFailure('The selected file is empty or too small to be a valid database.'));
      }

      // Check SQLite / SQLCipher header
      final headerBytes = await backupFile.openRead(0, 16).first;
      final headerStr = String.fromCharCodes(headerBytes);
      if (!headerStr.startsWith('SQLite format 3') && !headerStr.startsWith('SQLCipher')) {
        return const Failure(BackupFailure('The selected file is not a valid ClassKhata database snapshot.'));
      }

      try {
        await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      } catch (_) {}

      final dest = await _dbFile();

      // Copy the chosen file over the active DB
      await backupFile.copy(dest.path);

      // Clean up WAL and SHM companion files so stale transactions aren't replayed
      final walFile = File('${dest.path}-wal');
      if (walFile.existsSync()) {
        try {
          await walFile.delete();
        } catch (_) {}
      }
      final shmFile = File('${dest.path}-shm');
      if (shmFile.existsSync()) {
        try {
          await shmFile.delete();
        } catch (_) {}
      }

      // Record in backups table so it shows in the UI
      try {
        final checksum = await _sha256File(backupFile);
        final backupDir = await _backupDir();
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final archivedCopy = File(p.join(backupDir.path, 'imported_$ts.db'));
        await backupFile.copy(archivedCopy.path);

        await _db.into(_db.backupsMetaTable).insert(
              BackupsMetaTableCompanion.insert(
                filePath: archivedCopy.path,
                type: 'imported',
                sizeBytes: fileSize,
                checksum: checksum,
                createdBy: const Value(1),
                isVerified: const Value(true),
              ),
            );
      } catch (e) {
        await AppLogger.instance.warning('Could not record imported backup: $e');
      }

      await AppLogger.instance.info('Database restored from external file: ${backupFile.path}');
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('restoreFromFile failed', error: e, stack: st);
      return Failure(BackupFailure('Restore from file failed: $e', technicalDetail: e.toString()));
    }
  }

  @override
  Future<String> getBackupDirectoryPath() async {
    final dir = await _backupDir();
    return dir.path;
  }

  @override
  Future<Result<String>> exportBackup({int? backupId, String? targetFilePath}) async {
    try {
      String sourcePath;
      if (backupId != null) {
        final row = await (_db.select(_db.backupsMetaTable)..where((b) => b.id.equals(backupId))).getSingleOrNull();
        if (row == null) return const Failure(BackupFailure('Backup record not found.'));
        sourcePath = row.filePath;
      } else {
        final backupRes = await createBackup(type: 'manual', createdBy: 1);
        if (backupRes.isFailure) {
          return Failure(backupRes.fold(onSuccess: (_) => const BackupFailure(''), onFailure: (f) => f));
        }
        sourcePath = backupRes.valueOrThrow.filePath;
      }

      final srcFile = File(sourcePath);
      if (!srcFile.existsSync()) {
        return const Failure(BackupFailure('Backup source file does not exist on disk.'));
      }

      String destPath = targetFilePath ?? '';
      if (destPath.isEmpty) {
        final downloads = await getDownloadsDirectory();
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        destPath = p.join(downloads?.path ?? srcFile.parent.path, 'ClassKhata_Backup_$ts.db');
      }

      await srcFile.copy(destPath);
      return Success(destPath);
    } catch (e, st) {
      await AppLogger.instance.error('exportBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Export backup failed: $e'));
    }
  }

  Future<String> _sha256File(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<File> _dbFile() async {
    final dir = _overrideAppDir ?? await getApplicationSupportDirectory();
    return File(p.join(dir.path, AppConstants.dbFileName));
  }

  Future<Directory> _backupDir() async {
    final dir = _overrideAppDir ?? await getApplicationSupportDirectory();
    final backupDir = Directory(p.join(dir.path, AppConstants.backupDirName));
    if (!backupDir.existsSync()) await backupDir.create(recursive: true);
    return backupDir;
  }
}
