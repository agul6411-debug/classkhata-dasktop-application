/// Use case to collect fee payments with permission checks.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/fee_entities.dart';
import '../repositories/fee_repository.dart';

class CollectFeeUseCase {
  const CollectFeeUseCase(this._repository);
  final FeeRepository _repository;

  Future<Result<({Payment payment, Receipt receipt, FeeVoucher updatedVoucher})>> call({
    required Set<Permission> userPermissions,
    required int voucherId,
    required int studentId,
    required Money amount,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    // 1. Permission check in domain layer
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.feesCollect,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    // 2. Amount validation
    if (amount.isZero || amount.isNegative) {
      return const Failure(ValidationFailure('Collection amount must be greater than zero.'));
    }

    // 3. Delegate to repository
    return _repository.collectFee(
      voucherId: voucherId,
      studentId: studentId,
      amount: amount,
      paymentMode: paymentMode,
      referenceNumber: referenceNumber,
      createdBy: createdBy,
    );
  }
}
