/// Use cases for bulk voucher generation, maker-checker approvals, and aging analysis.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/fee_entities.dart';
import '../repositories/fee_repository.dart';

class GenerateVouchersUseCase {
  const GenerateVouchersUseCase(this._repository);
  final FeeRepository _repository;

  Future<Result<int>> call({
    required Set<Permission> userPermissions,
    required int batchId,
    required String monthYear,
    required DateTime dueDate,
    required int createdBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.feesVoucherGenerate,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (monthYear.trim().isEmpty) {
      return const Failure(ValidationFailure('Billing month/year is required.'));
    }

    return _repository.generateBatchVouchers(
      batchId: batchId,
      monthYear: monthYear.trim(),
      dueDate: dueDate,
      createdBy: createdBy,
    );
  }
}

class FeeApprovalsUseCase {
  const FeeApprovalsUseCase(this._repository);
  final FeeRepository _repository;

  /// Submits an approval request (Maker phase) for discount, refund, waiver, or cancellation.
  Future<Result<int>> requestAdjustment({
    required String type, // 'waiver', 'discount', 'refund', 'cancellation'
    required int voucherId,
    required Money amount,
    required String reason,
    required int requestedBy,
  }) async {
    if (reason.trim().isEmpty) {
      return const Failure(ValidationFailure('A reason is required for fee adjustments.'));
    }

    return _repository.requestFeeApproval(
      type: type,
      voucherId: voucherId,
      amount: amount,
      reason: reason.trim(),
      requestedBy: requestedBy,
    );
  }

  /// Reviews an approval request (Checker phase).
  /// Enforces:
  /// 1. The reviewer has approvalsApprove / approvalsReject permission.
  /// 2. Maker-checker rule: A user CANNOT approve their own request!
  Future<Result<void>> reviewAdjustment({
    required Set<Permission> userPermissions,
    required int requestId,
    required int requestedBy,
    required int reviewerId,
    required bool approve,
    String? reviewerNote,
    bool allowSingleAdminBypass = false,
  }) async {
    final requiredPerm =
        approve ? Permission.approvalsApprove : Permission.approvalsReject;
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: requiredPerm,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(
          onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    // Maker cannot be checker unless single-admin bypass is enabled for solo administrators
    if (requestedBy == reviewerId && !allowSingleAdminBypass) {
      return const Failure(ValidationFailure(
          'A user cannot approve their own request (maker-checker violation).'));
    }

    return _repository.reviewFeeApproval(
      requestId: requestId,
      reviewerId: reviewerId,
      approve: approve,
      reviewerNote: reviewerNote,
    );
  }
}

class DefaulterAgingUseCase {
  const DefaulterAgingUseCase(this._repository);
  final FeeRepository _repository;

  Future<Result<List<DefaulterAgingRecord>>> call({int? batchId}) {
    return _repository.getDefaulterAgingReport(batchId: batchId);
  }
}
