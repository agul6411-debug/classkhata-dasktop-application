/// Fee Management DAO with atomic transactions and gap-free receipt generation.
library;

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/audit_chain.dart';
import '../../../students/domain/services/student_profile_service.dart';
import '../../domain/entities/fee_entities.dart';

class FeeDao {
  const FeeDao(this._db);
  final AppDatabase _db;

  AppDatabase get db => _db;

  // ---------------------------------------------------------------------------
  // Vouchers
  // ---------------------------------------------------------------------------

  Future<List<FeeVouchersTableData>> getVouchers({
    int? batchId,
    int? studentId,
    VoucherStatus? status,
    String? monthYear,
  }) {
    final query = _db.select(_db.feeVouchersTable);
    if (batchId != null) query.where((t) => t.batchId.equals(batchId));
    if (studentId != null) query.where((t) => t.studentId.equals(studentId));
    if (status != null) query.where((t) => t.status.equals(status.name));
    if (monthYear != null) query.where((t) => t.monthYear.equals(monthYear));

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<FeeVouchersTableData?> getVoucherById(int id) =>
      (_db.select(_db.feeVouchersTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Atomic Fee Collection (Transaction: Voucher + Payment + Receipt + Audit)
  // ---------------------------------------------------------------------------

  Future<({
    PaymentsTableData payment,
    ReceiptsTableData receipt,
    FeeVouchersTableData voucher,
  })> collectFeeTransaction({
    required int voucherId,
    required int studentId,
    required int amountPaisa,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      // 1. Fetch current voucher
      final voucher = await (_db.select(_db.feeVouchersTable)
            ..where((t) => t.id.equals(voucherId)))
          .getSingle();

      final newPaidPaisa = voucher.amountPaidPaisa + amountPaisa;
      final newStatus = newPaidPaisa >= voucher.totalDuePaisa
          ? VoucherStatus.paid.name
          : VoucherStatus.partial.name;

      // 2. Atomic Gap-Free Sequential Receipt Number
      final receiptNumber = await _generateNextReceiptNumber();

      // 3. Insert Receipt with Verification QR payload
      final qrPayload = jsonEncode({
        'receipt': receiptNumber,
        'voucher': voucher.voucherNumber,
        'studentId': studentId,
        'amountPaisa': amountPaisa,
        'date': DateTime.now().toIso8601String(),
      });

      final receiptId = await _db.into(_db.receiptsTable).insert(
            ReceiptsTableCompanion.insert(
              receiptNumber: receiptNumber,
              voucherId: voucherId,
              studentId: studentId,
              amountPaisa: amountPaisa,
              qrData: qrPayload,
              createdBy: Value(createdBy),
            ),
          );

      // 4. Insert Payment record
      final paymentId = await _db.into(_db.paymentsTable).insert(
            PaymentsTableCompanion.insert(
              voucherId: voucherId,
              studentId: studentId,
              receiptId: receiptId,
              amountPaisa: amountPaisa,
              paymentMode: Value(paymentMode),
              referenceNumber: Value(referenceNumber),
              createdBy: Value(createdBy),
            ),
          );

      // 4b. Insert Cash Book Inflow
      final student = await (_db.select(_db.studentsTable)..where((t) => t.id.equals(studentId))).getSingleOrNull();
      await _db.into(_db.cashBookEntriesTable).insert(
            CashBookEntriesTableCompanion.insert(
              entryType: 'inflow',
              category: 'fee_payment',
              amountPaisa: amountPaisa,
              description: 'Fee collection: $receiptNumber (${student?.name ?? "Student #$studentId"})',
              paymentMode: Value(paymentMode),
              referenceId: Value(paymentId),
              entryDate: Value(DateTime.now()),
              createdBy: Value(createdBy),
            ),
          );

      // 5. Update Voucher status and paid balance
      await (_db.update(_db.feeVouchersTable)..where((t) => t.id.equals(voucherId))).write(
        FeeVouchersTableCompanion(
          amountPaidPaisa: Value(newPaidPaisa),
          status: Value(newStatus),
        ),
      );

      // 6. Write Hash-Chained Audit Log
      await _writeAuditEntry(
        action: 'fee.collected',
        entityType: 'Payment',
        entityId: paymentId.toString(),
        userId: createdBy,
        details: 'Collected Rs. ${(amountPaisa / 100).toStringAsFixed(2)} for Voucher ${voucher.voucherNumber} Receipt $receiptNumber',
      );

      // Return refreshed objects
      final updatedVoucher = await (_db.select(_db.feeVouchersTable)
            ..where((t) => t.id.equals(voucherId)))
          .getSingle();
      final createdReceipt = await (_db.select(_db.receiptsTable)
            ..where((t) => t.id.equals(receiptId)))
          .getSingle();
      final createdPayment = await (_db.select(_db.paymentsTable)
            ..where((t) => t.id.equals(paymentId)))
          .getSingle();

      return (
        payment: createdPayment,
        receipt: createdReceipt,
        voucher: updatedVoucher,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Gap-Free Receipt Number Generator
  // ---------------------------------------------------------------------------

  Future<String> _generateNextReceiptNumber() async {
    const series = 'RCP';
    final existingCounter = await (_db.select(_db.receiptCountersTable)
          ..where((t) => t.series.equals(series)))
        .getSingleOrNull();

    int nextNum = 1;
    if (existingCounter == null) {
      await _db.into(_db.receiptCountersTable).insert(
            ReceiptCountersTableCompanion.insert(
              series: series,
              currentNumber: const Value(1),
            ),
          );
      nextNum = 1;
    } else {
      nextNum = existingCounter.currentNumber + 1;
      await (_db.update(_db.receiptCountersTable)
            ..where((t) => t.id.equals(existingCounter.id)))
          .write(
            ReceiptCountersTableCompanion(
              currentNumber: Value(nextNum),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }

    return '$series-${nextNum.toString().padLeft(6, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Hash-Chained Audit Entry Writer
  // ---------------------------------------------------------------------------

  Future<void> _writeAuditEntry({
    required String action,
    required String entityType,
    required String entityId,
    required int userId,
    required String details,
  }) async {
    final lastAudit = await (_db.select(_db.auditLogTable)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();

    final prevHash = lastAudit?.entryHash ?? 'GENESIS';
    final now = DateTime.now();

    final entryHash = computeAuditHash(
      action: action,
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      createdAt: now,
      details: details,
      previousHash: prevHash,
    );

    await _db.into(_db.auditLogTable).insert(
          AuditLogTableCompanion.insert(
            action: action,
            entityType: entityType,
            entityId: Value(entityId),
            userId: userId,
            createdAt: Value(now),
            details: Value(details),
            previousHash: prevHash,
            entryHash: entryHash,
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Bulk Batch Voucher Generation
  // ---------------------------------------------------------------------------

  Future<int> generateBatchVouchers({
    required int batchId,
    required String monthYear,
    required DateTime dueDate,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      final batch = await (_db.select(_db.batchesTable)..where((t) => t.id.equals(batchId))).getSingle();
      final students = await (_db.select(_db.studentsTable)
            ..where((t) => t.batchId.equals(batchId) & t.status.equals('active')))
          .get();

      int count = 0;
      final now = DateTime.now();

      for (final student in students) {
        // Check if voucher already exists for student and monthYear
        final existing = await (_db.select(_db.feeVouchersTable)
              ..where((t) => t.studentId.equals(student.id) & t.monthYear.equals(monthYear)))
            .getSingleOrNull();

        if (existing != null) continue;

        // Check for previous unpaid carry-forward balance
        final prevVouchers = await (_db.select(_db.feeVouchersTable)
              ..where((t) =>
                  t.studentId.equals(student.id) &
                  (t.status.equals('unpaid') | t.status.equals('partial'))))
            .get();

        int carryForward = 0;
        for (final pv in prevVouchers) {
          carryForward += (pv.totalDuePaisa - pv.amountPaidPaisa);
        }

        final profile = await StudentProfileService.getProfile(db: _db, studentId: student.id);
        final discountPaisa = profile.monthlyDiscount * 100;
        final baseAmount = (profile.customMonthlyFee != null && profile.customMonthlyFee! > 0)
            ? profile.customMonthlyFee! * 100
            : batch.monthlyFeePaisa;
        final netDue = (baseAmount + carryForward) - discountPaisa;
        final totalDue = netDue > 0 ? netDue : 0;
        final vchNumber = 'VCH-$monthYear-${student.id.toString().padLeft(4, '0')}';

        await _db.into(_db.feeVouchersTable).insert(
              FeeVouchersTableCompanion.insert(
                voucherNumber: vchNumber,
                studentId: student.id,
                batchId: batchId,
                monthYear: monthYear,
                issueDate: now,
                dueDate: dueDate,
                baseAmountPaisa: Value(baseAmount),
                carryForwardPaisa: Value(carryForward),
                discountPaisa: Value(discountPaisa),
                totalDuePaisa: Value(totalDue),
                amountPaidPaisa: const Value(0),
                status: const Value('unpaid'),
                createdBy: Value(createdBy),
              ),
            );
        count++;
      }

      return count;
    });
  }

  // ---------------------------------------------------------------------------
  // Defaulter Aging
  // ---------------------------------------------------------------------------

  Future<List<DefaulterAgingRecord>> getDefaulterAgingReport({int? batchId}) async {
    final now = DateTime.now();
    final query = _db.select(_db.feeVouchersTable)
      ..where((t) =>
          (t.status.equals('unpaid') | t.status.equals('partial') | t.status.equals('overdue')) &
          t.dueDate.isSmallerThanValue(now));

    if (batchId != null) query.where((t) => t.batchId.equals(batchId));

    final overdueRows = await query.get();
    final Map<int, List<FeeVouchersTableData>> byStudent = {};

    for (final row in overdueRows) {
      byStudent.putIfAbsent(row.studentId, () => []).add(row);
    }

    final List<DefaulterAgingRecord> reports = [];

    for (final entry in byStudent.entries) {
      final studentId = entry.key;
      final studentVouchers = entry.value;

      final student = await (_db.select(_db.studentsTable)..where((t) => t.id.equals(studentId))).getSingleOrNull();
      if (student == null) continue;

      final batch = await (_db.select(_db.batchesTable)..where((t) => t.id.equals(student.batchId))).getSingleOrNull();

      int totalOverduePaisa = 0;
      int maxDaysOverdue = 0;

      for (final v in studentVouchers) {
        totalOverduePaisa += (v.totalDuePaisa - v.amountPaidPaisa);
        final diff = now.difference(v.dueDate).inDays;
        if (diff > maxDaysOverdue) maxDaysOverdue = diff;
      }

      reports.add(DefaulterAgingRecord(
        studentId: studentId,
        studentName: student.name,
        rollNumber: student.rollNumber,
        guardianPhone: student.guardianPhone,
        batchName: batch?.name ?? 'Batch #${student.batchId}',
        totalOverdue: Money.fromPaisa(totalOverduePaisa),
        daysOverdue: maxDaysOverdue,
        overdueVouchersCount: studentVouchers.length,
      ));
    }

    reports.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    return reports;
  }

  // ---------------------------------------------------------------------------
  // Receipts for Student
  // ---------------------------------------------------------------------------

  Future<List<ReceiptsTableData>> getReceiptsForStudent(int studentId) =>
      (_db.select(_db.receiptsTable)
            ..where((t) => t.studentId.equals(studentId))
            ..orderBy([(t) => OrderingTerm.desc(t.receiptDate)]))
          .get();

  // ---------------------------------------------------------------------------
  // Reversal / Cancellation
  // ---------------------------------------------------------------------------

  Future<void> cancelVoucher(int voucherId, String reason, int cancelledBy) async {
    await _db.transaction(() async {
      await (_db.update(_db.feeVouchersTable)..where((t) => t.id.equals(voucherId))).write(
        FeeVouchersTableCompanion(
          status: const Value('cancelled'),
          reversedAt: Value(DateTime.now()),
          reversedBy: Value(cancelledBy),
          reversalReason: Value(reason),
        ),
      );
      await _writeAuditEntry(
        action: 'voucher.cancelled',
        entityType: 'FeeVoucher',
        entityId: voucherId.toString(),
        userId: cancelledBy,
        details: 'Voucher #$voucherId cancelled. Reason: $reason',
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Approval Requests (Maker-Checker)
  // ---------------------------------------------------------------------------

  Future<int> insertApprovalRequest({
    required String type,
    required int voucherId,
    required int amountPaisa,
    required String reason,
    required int requestedBy,
  }) {
    final payload = jsonEncode({
      'voucherId': voucherId,
      'amountPaisa': amountPaisa,
      'type': type,
    });

    return _db.into(_db.approvalRequestsTable).insert(
          ApprovalRequestsTableCompanion.insert(
            type: type,
            entityType: 'FeeVoucher',
            entityId: voucherId.toString(),
            requestedBy: requestedBy,
            reason: reason,
            payload: payload,
          ),
        );
  }

  Future<void> reviewApprovalRequest({
    required int requestId,
    required int reviewerId,
    required bool approve,
    String? reviewerNote,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.approvalRequestsTable)..where((t) => t.id.equals(requestId))).write(
        ApprovalRequestsTableCompanion(
          status: Value(approve ? 'approved' : 'rejected'),
          reviewedBy: Value(reviewerId),
          reviewedAt: Value(DateTime.now()),
          reviewerNote: Value(reviewerNote),
        ),
      );
      await _writeAuditEntry(
        action: approve ? 'approval.approved' : 'approval.rejected',
        entityType: 'ApprovalRequest',
        entityId: requestId.toString(),
        userId: reviewerId,
        details:
            'Approval request #$requestId ${approve ? "approved" : "rejected"} by user #$reviewerId. Note: $reviewerNote',
      );
    });
  }
}
