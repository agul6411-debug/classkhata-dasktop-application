/// Fee repository implementation.
library;

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/fee_entities.dart';
import '../../domain/repositories/fee_repository.dart';
import '../datasources/fee_dao.dart';

class FeeRepositoryImpl implements FeeRepository {
  final FeeDao _dao;
  const FeeRepositoryImpl(this._dao);

  @override
  Future<Result<List<FeeVoucher>>> getVouchers({
    int? batchId,
    int? studentId,
    VoucherStatus? status,
    String? monthYear,
  }) async {
    try {
      final rows = await _dao.getVouchers(
        batchId: batchId,
        studentId: studentId,
        status: status,
        monthYear: monthYear,
      );
      final list = rows.map(_mapVoucherRow).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getVouchers error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch vouchers.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<FeeVoucher?>> getVoucherById(int id) async {
    try {
      final row = await _dao.getVoucherById(id);
      return Success(row != null ? _mapVoucherRow(row) : null);
    } catch (e, st) {
      await AppLogger.instance.error('getVoucherById error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch voucher.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<int>> generateBatchVouchers({
    required int batchId,
    required String monthYear,
    required DateTime dueDate,
    required int createdBy,
  }) async {
    try {
      final count = await _dao.generateBatchVouchers(
        batchId: batchId,
        monthYear: monthYear,
        dueDate: dueDate,
        createdBy: createdBy,
      );
      return Success(count);
    } catch (e, st) {
      await AppLogger.instance.error('generateBatchVouchers error', error: e, stack: st);
      return Failure(DatabaseFailure('Batch voucher generation failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<({Payment payment, Receipt receipt, FeeVoucher updatedVoucher})>> collectFee({
    required int voucherId,
    required int studentId,
    required Money amount,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    try {
      final txResult = await _dao.collectFeeTransaction(
        voucherId: voucherId,
        studentId: studentId,
        amountPaisa: amount.paisa,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        createdBy: createdBy,
      );

      final payment = Payment(
        id: txResult.payment.id,
        voucherId: txResult.payment.voucherId,
        studentId: txResult.payment.studentId,
        receiptId: txResult.payment.receiptId,
        amount: Money.fromPaisa(txResult.payment.amountPaisa),
        paymentMode: txResult.payment.paymentMode,
        referenceNumber: txResult.payment.referenceNumber,
        paymentDate: txResult.payment.paymentDate,
      );

      final receipt = Receipt(
        id: txResult.receipt.id,
        receiptNumber: txResult.receipt.receiptNumber,
        voucherId: txResult.receipt.voucherId,
        studentId: txResult.receipt.studentId,
        amount: Money.fromPaisa(txResult.receipt.amountPaisa),
        qrData: txResult.receipt.qrData,
        receiptDate: txResult.receipt.receiptDate,
        isCancelled: txResult.receipt.isCancelled,
      );

      final voucher = _mapVoucherRow(txResult.voucher);

      return Success((payment: payment, receipt: receipt, updatedVoucher: voucher));
    } catch (e, st) {
      await AppLogger.instance.error('collectFee error', error: e, stack: st);
      return Failure(DatabaseFailure('Fee collection transaction failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> cancelVoucher({
    required int voucherId,
    required String reason,
    required int cancelledBy,
  }) async {
    try {
      await _dao.cancelVoucher(voucherId, reason, cancelledBy);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('cancelVoucher error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not cancel voucher.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<int>> requestFeeApproval({
    required String type,
    required int voucherId,
    required Money amount,
    required String reason,
    required int requestedBy,
  }) async {
    try {
      final id = await _dao.insertApprovalRequest(
        type: type,
        voucherId: voucherId,
        amountPaisa: amount.paisa,
        reason: reason,
        requestedBy: requestedBy,
      );
      return Success(id);
    } catch (e, st) {
      await AppLogger.instance.error('requestFeeApproval error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not submit approval request.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> reviewFeeApproval({
    required int requestId,
    required int reviewerId,
    required bool approve,
    String? reviewerNote,
  }) async {
    try {
      await _dao.reviewApprovalRequest(
        requestId: requestId,
        reviewerId: reviewerId,
        approve: approve,
        reviewerNote: reviewerNote,
      );
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('reviewFeeApproval error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not review approval request.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<DefaulterAgingRecord>>> getDefaulterAgingReport({int? batchId}) async {
    try {
      final report = await _dao.getDefaulterAgingReport(batchId: batchId);
      return Success(report);
    } catch (e, st) {
      await AppLogger.instance.error('getDefaulterAgingReport error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not generate defaulter aging report.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Receipt>>> getReceiptsForStudent(int studentId) async {
    try {
      final rows = await _dao.getReceiptsForStudent(studentId);
      final list = rows.map((r) => Receipt(
            id: r.id,
            receiptNumber: r.receiptNumber,
            voucherId: r.voucherId,
            studentId: r.studentId,
            amount: Money.fromPaisa(r.amountPaisa),
            qrData: r.qrData,
            receiptDate: r.receiptDate,
            isCancelled: r.isCancelled,
            cancellationReason: r.cancellationReason,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getReceiptsForStudent error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch receipts.', technicalDetail: e.toString()));
    }
  }

  FeeVoucher _mapVoucherRow(FeeVouchersTableData r) {
    return FeeVoucher(
      id: r.id,
      voucherNumber: r.voucherNumber,
      studentId: r.studentId,
      batchId: r.batchId,
      monthYear: r.monthYear,
      issueDate: r.issueDate,
      dueDate: r.dueDate,
      baseAmount: Money.fromPaisa(r.baseAmountPaisa),
      discount: Money.fromPaisa(r.discountPaisa),
      lateFee: Money.fromPaisa(r.lateFeePaisa),
      carryForward: Money.fromPaisa(r.carryForwardPaisa),
      totalDue: Money.fromPaisa(r.totalDuePaisa),
      amountPaid: Money.fromPaisa(r.amountPaidPaisa),
      status: VoucherStatus.fromString(r.status),
      createdAt: r.createdAt,
      reversedAt: r.reversedAt,
      reversalReason: r.reversalReason,
    );
  }
}
