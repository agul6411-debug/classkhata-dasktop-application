/// Pure domain fee calculator logic.
///
/// Implements calculations for total due, voucher statuses, and carry-forward balances.
library;

import '../../../../core/money/money.dart';
import '../entities/fee_entities.dart';

class FeeCalculator {
  FeeCalculator._();

  /// Calculates total due: (baseAmount - discount) + lateFee + carryForward.
  static Money calculateTotalDue({
    required Money baseAmount,
    required Money discount,
    required Money lateFee,
    required Money carryForward,
  }) {
    final netBase = (baseAmount - discount);
    final adjustedBase = netBase.isNegative ? const Money(0) : netBase;
    return adjustedBase + lateFee + carryForward;
  }

  /// Determines the voucher status based on payment and due date.
  static VoucherStatus determineStatus({
    required Money totalDue,
    required Money amountPaid,
    required DateTime dueDate,
    DateTime? now,
  }) {
    final currentDate = now ?? DateTime.now();
    if (amountPaid >= totalDue && totalDue.isPositive) {
      return VoucherStatus.paid;
    }
    if (amountPaid.isPositive && amountPaid < totalDue) {
      return currentDate.isAfter(dueDate) ? VoucherStatus.overdue : VoucherStatus.partial;
    }
    if (currentDate.isAfter(dueDate)) {
      return VoucherStatus.overdue;
    }
    return VoucherStatus.unpaid;
  }

  /// Calculates carry-forward balance for next month: (totalDue - amountPaid).
  static Money calculateCarryForward({
    required Money totalDue,
    required Money amountPaid,
  }) {
    final remaining = totalDue - amountPaid;
    return remaining.isPositive ? remaining : const Money(0);
  }
}
