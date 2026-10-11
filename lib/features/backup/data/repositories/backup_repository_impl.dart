/// Backup repository implementation.
///
/// Creates a file copy of the database (already encrypted by SQLCipher).
/// Computes a SHA-256 checksum and records it in the DB.
library;

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/backup_meta.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  final AppDatabase _db;
  final Directory? _overrideAppDir;

  const BackupRepositoryImpl(this._db, {Directory? overrideAppDir})
      : _overrideAppDir = overrideAppDir;

  @override
  Future<Result<BackupMeta>> createBackup({
    required String type,
    required int createdBy,
  }) async {
    try {
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
      if (verifyResult.isFailure) return Failure(verifyResult.fold(
        onSuccess: (_) => const BackupFailure(''),
        onFailure: (f) => f,
      ));
      if (!verifyResult.valueOrThrow) {
        return const Failure(BackupFailure('Backup checksum mismatch. Restore aborted.'));
      }

      final row = await (_db.select(_db.backupsMetaTable)
            ..where((b) => b.id.equals(backupId)))
          .getSingle();

      final src = File(row.filePath);
      final dest = await _dbFile();

      await src.copy(dest.path);
      await AppLogger.instance.info('Backup restored from ${src.path}. Restart required.');
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('restoreBackup failed', error: e, stack: st);
      return Failure(BackupFailure('Restore failed.', technicalDetail: e.toString()));
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
