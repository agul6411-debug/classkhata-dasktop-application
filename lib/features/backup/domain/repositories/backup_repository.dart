/// Abstract backup repository.
library;

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
}
