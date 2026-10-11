/// Abstract repository for Payroll.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/payroll_entities.dart';

abstract interface class PayrollRepository {
  // Staff
  Future<Result<List<StaffMember>>> getStaffMembers({StaffStatus? status});
  Future<Result<StaffMember>> createStaffMember({
    required String name,
    required String phone,
    required String designation,
    String? cnic,
    required int createdBy,
  });

  // Salary Structures
  Future<Result<SalaryStructure?>> getSalaryStructure(int staffId);
  Future<Result<void>> setSalaryStructure({
    required int staffId,
    required String structureType,
    required Money baseAmount,
    required Money allowances,
    required Money deductions,
    required int createdBy,
  });

  // Payroll Runs
  Future<Result<List<PayrollRun>>> getPayrollRuns({String? monthYear});
  Future<Result<int>> runMonthlyPayroll({
    required String monthYear,
    required int createdBy,
  });
  Future<Result<void>> paySalary({
    required int payrollRunId,
    required String paymentMode,
    required int paidBy,
  });

  // Advances
  Future<Result<List<StaffAdvance>>> getStaffAdvances({int? staffId});
  Future<Result<StaffAdvance>> issueAdvance({
    required int staffId,
    required Money amount,
    String? reason,
    required int createdBy,
  });
}
