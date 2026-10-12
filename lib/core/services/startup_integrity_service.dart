/// Startup system integrity checks.
///
/// Verifies:
/// 1. Database file integrity via SQLite PRAGMA integrity_check.
/// 2. Hash-chained financial audit log integrity via SHA-256 verification.
/// 3. Automated backup directory accessibility and write permissions.
///
/// Emits user-friendly, non-technical warnings when integrity issues occur.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../security/audit_chain.dart';

class IntegrityCheckResult {
  final bool dbHealthy;
  final bool auditChainHealthy;
  final bool backupFolderHealthy;
  final String? userFriendlyMessage;
  final List<String> technicalDetails;

  const IntegrityCheckResult({
    required this.dbHealthy,
    required this.auditChainHealthy,
    required this.backupFolderHealthy,
    this.userFriendlyMessage,
    this.technicalDetails = const [],
  });

  bool get isHealthy => dbHealthy && auditChainHealthy && backupFolderHealthy;
}

class StartupIntegrityService {
  final AppDatabase _db;
  final Directory _backupDir;

  StartupIntegrityService(this._db, this._backupDir);

  /// Performs full system integrity checks on app launch.
  Future<IntegrityCheckResult> runStartupChecks() async {
    final technicalDetails = <String>[];
    bool dbHealthy = true;
    bool auditHealthy = true;
    bool backupHealthy = true;

    // 1. SQLite Database Integrity Check
    try {
      final rows = await _db.customSelect('PRAGMA integrity_check;').get();
      final result = rows.isNotEmpty ? rows.first.data.values.first.toString() : 'unknown';
      if (result.toLowerCase() != 'ok') {
        dbHealthy = false;
        technicalDetails.add('SQLite integrity check reported: $result');
      }
    } catch (e) {
      dbHealthy = false;
      technicalDetails.add('SQLite check failed to run: $e');
    }

    // 2. Audit Chain Verification
    try {
      final rows = await (_db.select(_db.auditLogTable)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      if (rows.isNotEmpty) {
        final entries = rows.map((r) => AuditEntry(
          id: r.id,
          action: r.action,
          entityType: r.entityType,
          entityId: r.entityId,
          userId: r.userId,
          createdAt: r.createdAt,
          details: r.details,
          previousHash: r.previousHash,
          entryHash: r.entryHash,
        )).toList();

        final auditResult = verifyAuditChain(entries);
        auditResult.fold(
          onSuccess: (_) {},
          onFailure: (f) {
            auditHealthy = false;
            technicalDetails.add('Audit log chain invalid: ${f.message}');
          },
        );
      }
    } catch (e) {
      auditHealthy = false;
      technicalDetails.add('Audit verification failed: $e');
    }

    // 3. Backup Folder Accessibility
    try {
      if (!_backupDir.existsSync()) {
        _backupDir.createSync(recursive: true);
      }
      final testFile = File('${_backupDir.path}${Platform.pathSeparator}.write_test.tmp');
      testFile.writeAsStringSync('write_test');
      testFile.deleteSync();
    } catch (e) {
      backupHealthy = false;
      technicalDetails.add('Backup directory write failed: $e');
    }

    // Generate plain-language, non-technical warning if any check fails
    String? friendlyMessage;
    if (!dbHealthy) {
      friendlyMessage = 'Data Storage Alert: The database file appears corrupted or incomplete. '
          'Please restore from your latest backup or contact technical support.';
    } else if (!auditHealthy) {
      friendlyMessage = 'Security Alert: The system detected that the financial audit log records '
          'may have been modified or damaged. All data remains viewable, but please verify recent transactions.';
    } else if (!backupHealthy) {
      friendlyMessage = 'Backup Storage Warning: ClassKhata cannot save backups to the configured backup folder. '
          'Please verify storage permissions in Settings.';
    }

    if (friendlyMessage != null) {
      await AppLogger.instance.warning('Startup integrity warning: $friendlyMessage');
    } else {
      await AppLogger.instance.info('Startup integrity checks passed: Database, Audit Chain, and Backup folder OK.');
    }

    return IntegrityCheckResult(
      dbHealthy: dbHealthy,
      auditChainHealthy: auditHealthy,
      backupFolderHealthy: backupHealthy,
      userFriendlyMessage: friendlyMessage,
      technicalDetails: technicalDetails,
    );
  }
}
