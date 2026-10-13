import 'package:classkhata/core/constants/app_constants.dart';
import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/core/security/audit_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Audit Chain', () {
    AuditEntry makeEntry({
      required int id,
      required String previousHash,
      String action = 'test.action',
      String entityType = 'TestEntity',
      int userId = 1,
    }) {
      final hash = computeAuditHash(
        action: action,
        entityType: entityType,
        userId: userId,
        createdAt: DateTime(2026, 1, 1, id), // deterministic timestamp per id
        previousHash: previousHash,
      );
      return AuditEntry(
        id: id,
        action: action,
        entityType: entityType,
        userId: userId,
        createdAt: DateTime(2026, 1, 1, id),
        previousHash: previousHash,
        entryHash: hash,
      );
    }

    test('empty chain is valid', () {
      final result = verifyAuditChain([]);
      expect(result.isSuccess, true);
    });

    test('single genesis entry is valid', () {
      final entry = makeEntry(id: 1, previousHash: AppConstants.auditChainGenesisHash);
      final result = verifyAuditChain([entry]);
      expect(result.isSuccess, true);
    });

    test('chain of three entries is valid', () {
      final e1 = makeEntry(id: 1, previousHash: AppConstants.auditChainGenesisHash);
      final e2 = makeEntry(id: 2, previousHash: e1.entryHash);
      final e3 = makeEntry(id: 3, previousHash: e2.entryHash);
      final result = verifyAuditChain([e1, e2, e3]);
      expect(result.isSuccess, true);
    });

    test('tampered entry hash is detected', () {
      final e1 = makeEntry(id: 1, previousHash: AppConstants.auditChainGenesisHash);
      final e2 = makeEntry(id: 2, previousHash: e1.entryHash);
      // Tamper: replace e2's hash with a fake one
      final tampered = AuditEntry(
        id: e2.id,
        action: e2.action,
        entityType: e2.entityType,
        userId: e2.userId,
        createdAt: e2.createdAt,
        previousHash: e2.previousHash,
        entryHash: 'FAKE_HASH_ABCDEF',
      );
      final result = verifyAuditChain([e1, tampered]);
      expect(result.isFailure, true);
      expect(result.fold(
        onSuccess: (_) => '',
        onFailure: (f) => f,
      ), isA<IntegrityFailure>());
    });

    test('broken previousHash link is detected', () {
      final e1 = makeEntry(id: 1, previousHash: AppConstants.auditChainGenesisHash);
      // e2 references a wrong previous hash
      final e2 = makeEntry(id: 2, previousHash: 'WRONG_PREVIOUS_HASH');
      final result = verifyAuditChain([e1, e2]);
      expect(result.isFailure, true);
    });

    test('deleted middle entry is detected', () {
      final e1 = makeEntry(id: 1, previousHash: AppConstants.auditChainGenesisHash);
      final e2 = makeEntry(id: 2, previousHash: e1.entryHash);
      final e3 = makeEntry(id: 3, previousHash: e2.entryHash);
      // Skip e2 (simulate deletion)
      final result = verifyAuditChain([e1, e3]);
      expect(result.isFailure, true);
    });

    test('computeAuditHash is deterministic', () {
      final h1 = computeAuditHash(
        action: 'pay',
        entityType: 'Payment',
        userId: 1,
        createdAt: DateTime(2026),
        previousHash: 'prev',
      );
      final h2 = computeAuditHash(
        action: 'pay',
        entityType: 'Payment',
        userId: 1,
        createdAt: DateTime(2026),
        previousHash: 'prev',
      );
      expect(h1, equals(h2));
    });
  });
}
