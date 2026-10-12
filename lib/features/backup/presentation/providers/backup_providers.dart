/// Riverpod providers for Backup & Audit Integrity management.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/security/audit_chain.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/entities/backup_meta.dart';
import '../../domain/repositories/backup_repository.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupRepositoryImpl(db);
});

final backupsListProvider = FutureProvider<List<BackupMeta>>((ref) async {
  final repo = ref.watch(backupRepositoryProvider);
  final res = await repo.listBackups();
  return res.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Verifies the entire cryptographic SHA-256 hash chain of the audit log.
final verifyAuditLogProvider = FutureProvider<Result<bool>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.auditLogTable)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

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

  return verifyAuditChain(entries);
});

final backupSchedulerServiceProvider = Provider<BackupSchedulerService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(backupRepositoryProvider);
  return BackupSchedulerService(db, repo);
});
