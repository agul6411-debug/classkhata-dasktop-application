/// Domain entities for Fee Management.
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

enum VoucherStatus {
  unpaid,
  partial,
  paid,
  overdue,
  cancelled;

  static VoucherStatus fromString(String val) {
    return switch (val.toLowerCase()) {
      'unpaid' => VoucherStatus.unpaid,
      'partial' => VoucherStatus.partial,
      'paid' => VoucherStatus.paid,
      'overdue' => VoucherStatus.overdue,
      'cancelled' => VoucherStatus.cancelled,
      _ => VoucherStatus.unpaid,
    };
  }
}

class FeeVoucher extends Equatable {
  final int id;
  final String voucherNumber;
  final int studentId;
  final int batchId;
  final String monthYear; // e.g. "2026-10"
  final DateTime issueDate;
  final DateTime dueDate;
  final Money baseAmount;
  final Money discount;
  final Money lateFee;
  final Money carryForward;
  final Money totalDue;
  final Money amountPaid;
  final VoucherStatus status;
  final DateTime createdAt;
  final DateTime? reversedAt;
  final String? reversalReason;

  const FeeVoucher({
    required this.id,
    required this.voucherNumber,
    required this.studentId,
    required this.batchId,
    required this.monthYear,
    required this.issueDate,
    required this.dueDate,
    required this.baseAmount,
    required this.discount,
    required this.lateFee,
    required this.carryForward,
    required this.totalDue,
    required this.amountPaid,
    required this.status,
    required this.createdAt,
    this.reversedAt,
    this.reversalReason,
  });

  /// The unpaid balance remaining on this voucher.
  Money get balanceRemaining => totalDue - amountPaid;

  bool get isPaidInFull => balanceRemaining.isZero || balanceRemaining.isNegative;

  @override
  List<Object?> get props => [
        id,
        voucherNumber,
        studentId,
        batchId,
        monthYear,
        issueDate,
        dueDate,
        baseAmount,
        discount,
        lateFee,
        carryForward,
        totalDue,
        amountPaid,
        status,
        createdAt,
        reversedAt,
      ];
}

class Payment extends Equatable {
  final int id;
  final int voucherId;
  final int studentId;
  final int receiptId;
  final Money amount;
  final String paymentMode;
  final String? referenceNumber;
  final DateTime paymentDate;
  final DateTime? reversedAt;
  final String? reversalReason;

  const Payment({
    required this.id,
    required this.voucherId,
    required this.studentId,
    required this.receiptId,
    required this.amount,
    required this.paymentMode,
    this.referenceNumber,
    required this.paymentDate,
    this.reversedAt,
    this.reversalReason,
  });

  @override
  List<Object?> get props => [
        id,
        voucherId,
        studentId,
        receiptId,
        amount,
        paymentMode,
        referenceNumber,
        paymentDate,
        reversedAt,
      ];
}

class Receipt extends Equatable {
  final int id;
  final String receiptNumber;
  final int voucherId;
  final int studentId;
  final Money amount;
  final String qrData;
  final DateTime receiptDate;
  final bool isCancelled;
  final String? cancellationReason;

  const Receipt({
    required this.id,
    required this.receiptNumber,
    required this.voucherId,
    required this.studentId,
    required this.amount,
    required this.qrData,
    required this.receiptDate,
    required this.isCancelled,
    this.cancellationReason,
  });

  @override
  List<Object?> get props => [
        id,
        receiptNumber,
        voucherId,
        studentId,
        amount,
        qrData,
        receiptDate,
        isCancelled,
      ];
}

class DefaulterAgingRecord extends Equatable {
  final int studentId;
  final String studentName;
  final String rollNumber;
  final String guardianPhone;
  final String batchName;
  final Money totalOverdue;
  final int daysOverdue; // e.g. 15, 35, 65, 95
  final int overdueVouchersCount;

  const DefaulterAgingRecord({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.guardianPhone,
    required this.batchName,
    required this.totalOverdue,
    required this.daysOverdue,
    required this.overdueVouchersCount,
  });

  /// Aging category
  String get bucket => switch (daysOverdue) {
        >= 90 => '90+ Days',
        >= 60 => '60-89 Days',
        >= 30 => '30-59 Days',
        _ => 'Current (<30 Days)',
      };

  @override
  List<Object?> get props => [
        studentId,
        studentName,
        rollNumber,
        guardianPhone,
        batchName,
        totalOverdue,
        daysOverdue,
        overdueVouchersCount,
      ];
}
