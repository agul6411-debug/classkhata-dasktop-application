/// Abstract repository for Fee Management.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/fee_entities.dart';

abstract interface class FeeRepository {
  // Vouchers
  Future<Result<List<FeeVoucher>>> getVouchers({
    int? batchId,
    int? studentId,
    VoucherStatus? status,
    String? monthYear,
  });

  Future<Result<FeeVoucher?>> getVoucherById(int id);

  Future<Result<int>> generateBatchVouchers({
    required int batchId,
    required String monthYear,
    required DateTime dueDate,
    required int createdBy,
  });

  // Fee Collection (3-Step transaction with gap-free receipt generation)
  Future<Result<({Payment payment, Receipt receipt, FeeVoucher updatedVoucher})>> collectFee({
    required int voucherId,
    required int studentId,
    required Money amount,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  });

  // Reversal / Cancellation
  Future<Result<void>> cancelVoucher({
    required int voucherId,
    required String reason,
    required int cancelledBy,
  });

  // Maker-Checker Approvals
  Future<Result<int>> requestFeeApproval({
    required String type, // 'waiver', 'discount', 'refund', 'cancellation'
    required int voucherId,
    required Money amount,
    required String reason,
    required int requestedBy,
  });

  // Defaulter Aging
  Future<Result<List<DefaulterAgingRecord>>> getDefaulterAgingReport({int? batchId});

  // Receipts
  Future<Result<List<Receipt>>> getReceiptsForStudent(int studentId);
}
