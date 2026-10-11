/// Domain entities for Payroll management.
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

enum StaffStatus {
  active,
  inactive,
  resigned;

  static StaffStatus fromString(String val) {
    return switch (val.toLowerCase()) {
      'active' => StaffStatus.active,
      'inactive' => StaffStatus.inactive,
      'resigned' => StaffStatus.resigned,
      _ => StaffStatus.active,
    };
  }
}

class StaffMember extends Equatable {
  final int id;
  final String staffCode;
  final String name;
  final String phone;
  final String designation;
  final String? cnic;
  final DateTime joiningDate;
  final StaffStatus status;

  const StaffMember({
    required this.id,
    required this.staffCode,
    required this.name,
    required this.phone,
    required this.designation,
    this.cnic,
    required this.joiningDate,
    required this.status,
  });

  @override
  List<Object?> get props => [id, staffCode, name, phone, designation, cnic, joiningDate, status];
}

class SalaryStructure extends Equatable {
  final int id;
  final int staffId;
  final String structureType; // 'fixed', 'per_class', 'per_hour'
  final Money baseAmount;
  final Money allowances;
  final Money deductions;
  final bool isActive;

  const SalaryStructure({
    required this.id,
    required this.staffId,
    required this.structureType,
    required this.baseAmount,
    required this.allowances,
    required this.deductions,
    required this.isActive,
  });

  Money get grossSalary => baseAmount + allowances;
  Money get netSalary => grossSalary - deductions;

  @override
  List<Object?> get props => [id, staffId, structureType, baseAmount, allowances, deductions, isActive];
}

class PayrollRun extends Equatable {
  final int id;
  final String monthYear;
  final int staffId;
  final String staffName;
  final String designation;
  final Money baseSalary;
  final Money allowances;
  final Money deductions;
  final Money advanceRecovery;
  final Money netSalary;
  final String status; // 'unpaid', 'paid'
  final DateTime? paidAt;
  final String? paymentMode;

  const PayrollRun({
    required this.id,
    required this.monthYear,
    required this.staffId,
    required this.staffName,
    required this.designation,
    required this.baseSalary,
    required this.allowances,
    required this.deductions,
    required this.advanceRecovery,
    required this.netSalary,
    required this.status,
    this.paidAt,
    this.paymentMode,
  });

  bool get isPaid => status.toLowerCase() == 'paid';

  @override
  List<Object?> get props => [
        id,
        monthYear,
        staffId,
        staffName,
        designation,
        baseSalary,
        allowances,
        deductions,
        advanceRecovery,
        netSalary,
        status,
        paidAt,
        paymentMode,
      ];
}

class StaffAdvance extends Equatable {
  final int id;
  final int staffId;
  final Money amount;
  final Money recovered;
  final Money remaining;
  final String? reason;
  final DateTime issueDate;

  const StaffAdvance({
    required this.id,
    required this.staffId,
    required this.amount,
    required this.recovered,
    required this.remaining,
    this.reason,
    required this.issueDate,
  });

  bool get isFullyRecovered => remaining.isZero || remaining.isNegative;

  @override
  List<Object?> get props => [id, staffId, amount, recovered, remaining, reason, issueDate];
}
