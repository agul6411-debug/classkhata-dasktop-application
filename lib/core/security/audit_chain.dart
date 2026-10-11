/// Hash-chained audit log service.
///
/// Each audit entry stores the SHA-256 hash of the *previous* entry's
/// serialized content. This creates a tamper-evident chain: if any entry
/// is modified or deleted, the chain verification will detect it.
///
/// The first entry (genesis) uses the constant [AppConstants.auditChainGenesisHash]
/// as its previousHash.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';

/// The data written to one audit log entry.
class AuditEntry {
  final int id;
  final String action;
  final String entityType;
  final String? entityId;
  final int userId;
  final DateTime createdAt;
  final String? details;
  final String previousHash;
  final String entryHash;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.userId,
    required this.createdAt,
    this.details,
    required this.previousHash,
    required this.entryHash,
  });
}

/// Computes the hash for a new audit log entry.
///
/// [previousHash] is the [entryHash] of the most recent existing entry,
/// or [AppConstants.auditChainGenesisHash] for the very first entry.
String computeAuditHash({
  required String action,
  required String entityType,
  String? entityId,
  required int userId,
  required DateTime createdAt,
  String? details,
  required String previousHash,
}) {
  final payload = jsonEncode({
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'details': details,
    'previousHash': previousHash,
  });
  return sha256.convert(utf8.encode(payload)).toString();
}

/// Verifies the integrity of a list of [AuditEntry] objects.
///
/// Returns [Success(true)] if the chain is intact, [Failure] if tampered.
Result<bool> verifyAuditChain(List<AuditEntry> entries) {
  if (entries.isEmpty) return const Success(true);

  String expectedPrevHash = AppConstants.auditChainGenesisHash;

  for (final entry in entries) {
    if (entry.previousHash != expectedPrevHash) {
      AppLogger.instance.warning(
        'Audit chain broken at entry ${entry.id}: '
        'expected previousHash=$expectedPrevHash, got=${entry.previousHash}',
      );
      return Failure(
        IntegrityFailure(
          'Audit log integrity check failed at entry ${entry.id}. '
          'The audit log may have been tampered with.',
        ),
      );
    }

    final expectedHash = computeAuditHash(
      action: entry.action,
      entityType: entry.entityType,
      entityId: entry.entityId,
      userId: entry.userId,
      createdAt: entry.createdAt,
      details: entry.details,
      previousHash: entry.previousHash,
    );

    if (entry.entryHash != expectedHash) {
      AppLogger.instance.warning(
        'Audit chain: entry ${entry.id} hash mismatch. '
        'Expected=$expectedHash, stored=${entry.entryHash}',
      );
      return Failure(
        IntegrityFailure(
          'Audit log entry ${entry.id} has been tampered with.',
        ),
      );
    }

    expectedPrevHash = entry.entryHash;
  }

  return const Success(true);
}
