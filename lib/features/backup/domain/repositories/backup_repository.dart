import 'dart:io';

import '../../../../core/errors/failures.dart';
import '../entities/backup_meta.dart';

abstract interface class BackupRepository {
  /// Creates a timestamped encrypted backup of the DB file.
  /// [type] is 'manual', 'auto', or 'pre_migration'.
  Future<Result<BackupMeta>> createBackup({required String type, required int createdBy});

  /// Returns all backup records, newest first.
  Future<Result<List<BackupMeta>>> listBackups();

  /// Verifies the checksum of the backup at [backupId].
  Future<Result<bool>> verifyBackup(int backupId);

  /// Restores the database from [backupId].
  /// Requires app restart after this call.
  Future<Result<void>> restoreBackup(int backupId);

  /// Restores the database from an external file on disk.
  /// Requires app restart after this call.
  Future<Result<void>> restoreFromFile(File backupFile);

  /// Returns the absolute path of the backup directory.
  Future<String> getBackupDirectoryPath();

  /// Exports a backup to a specified target file path.
  Future<Result<String>> exportBackup({int? backupId, String? targetFilePath});
}
