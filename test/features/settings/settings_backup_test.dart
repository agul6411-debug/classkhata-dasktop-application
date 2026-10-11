import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/constants/app_constants.dart';
import 'package:classkhata/core/security/audit_chain.dart';

void main() {
  group('Settings, Backup Integrity & Audit Chain Verification', () {
    test('Audit chain computes SHA-256 and verifies intact sequence', () {
      final now1 = DateTime(2026, 10, 11, 10, 0, 0);
      final now2 = DateTime(2026, 10, 11, 10, 5, 0);

      // Entry 1 (Genesis)
      final hash1 = computeAuditHash(
        action: 'user.login',
        entityType: 'User',
        entityId: '1',
        userId: 1,
        createdAt: now1,
        details: 'Admin login',
        previousHash: AppConstants.auditChainGenesisHash,
      );

      final entry1 = AuditEntry(
        id: 1,
        action: 'user.login',
        entityType: 'User',
        entityId: '1',
        userId: 1,
        createdAt: now1,
        details: 'Admin login',
        previousHash: AppConstants.auditChainGenesisHash,
        entryHash: hash1,
      );

      // Entry 2
      final hash2 = computeAuditHash(
        action: 'fee.collected',
        entityType: 'Payment',
        entityId: '101',
        userId: 1,
        createdAt: now2,
        details: 'Fee payment Rs 5000',
        previousHash: hash1,
      );

      final entry2 = AuditEntry(
        id: 2,
        action: 'fee.collected',
        entityType: 'Payment',
        entityId: '101',
        userId: 1,
        createdAt: now2,
        details: 'Fee payment Rs 5000',
        previousHash: hash1,
        entryHash: hash2,
      );

      final validChain = [entry1, entry2];
      final res = verifyAuditChain(validChain);
      expect(res.isSuccess, true);
      expect(res.valueOrThrow, true);
    });

    test('Audit chain detects tampered records or modified hashes', () {
      final now = DateTime(2026, 10, 11, 12, 0, 0);

      // Tampered entry with fraudulent hash
      final tamperedEntry = AuditEntry(
        id: 1,
        action: 'backup.created',
        entityType: 'Backup',
        userId: 1,
        createdAt: now,
        details: 'Manual backup',
        previousHash: AppConstants.auditChainGenesisHash,
        entryHash: 'fraudulent_sha256_hash_12345',
      );

      final res = verifyAuditChain([tamperedEntry]);
      expect(res.isFailure, true);
    });

    test('Audit chain detects broken link between consecutive records', () {
      final now1 = DateTime(2026, 10, 11, 14, 0, 0);
      final now2 = DateTime(2026, 10, 11, 14, 1, 0);

      final hash1 = computeAuditHash(
        action: 'expense.created',
        entityType: 'Expense',
        userId: 1,
        createdAt: now1,
        previousHash: AppConstants.auditChainGenesisHash,
      );

      final entry1 = AuditEntry(
        id: 1,
        action: 'expense.created',
        entityType: 'Expense',
        userId: 1,
        createdAt: now1,
        previousHash: AppConstants.auditChainGenesisHash,
        entryHash: hash1,
      );

      // Entry 2 points to incorrect previousHash
      final brokenEntry2 = AuditEntry(
        id: 2,
        action: 'expense.created',
        entityType: 'Expense',
        userId: 1,
        createdAt: now2,
        previousHash: 'wrong_broken_previous_hash',
        entryHash: 'any_hash',
      );

      final res = verifyAuditChain([entry1, brokenEntry2]);
      expect(res.isFailure, true);
    });
  });
}
