/// Payroll domain use cases.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/payroll_entities.dart';
import '../repositories/payroll_repository.dart';

class CalculateSalaryEngine {
  CalculateSalaryEngine._();

  /// Calculates net payable salary: (base + allowances) - deductions - advanceRecovery.
  static Money calculateNetSalary({
    required Money baseSalary,
    required Money allowances,
    required Money deductions,
    required Money advanceRecovery,
  }) {
    final gross = baseSalary + allowances;
    final totalDeductions = deductions + advanceRecovery;
    final net = gross - totalDeductions;
    return net.isNegative ? const Money(0) : net;
  }
}

class CreateStaffMemberUseCase {
  final PayrollRepository _repository;
  const CreateStaffMemberUseCase(this._repository);

  Future<Result<StaffMember>> call({
    required String name,
    required String phone,
    required String designation,
    String? cnic,
    required int createdBy,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(ValidationFailure('Staff member name is required.'));
    }
    if (phone.trim().isEmpty) {
      return const Failure(ValidationFailure('Staff phone number is required.'));
    }
    if (designation.trim().isEmpty) {
      return const Failure(ValidationFailure('Designation is required.'));
    }

    return _repository.createStaffMember(
      name: name.trim(),
      phone: phone.trim(),
      designation: designation.trim(),
      cnic: cnic?.trim().isEmpty ?? true ? null : cnic!.trim(),
      createdBy: createdBy,
    );
  }
}

class RunMonthlyPayrollUseCase {
  final PayrollRepository _repository;
  const RunMonthlyPayrollUseCase(this._repository);

  Future<Result<int>> call({
    required Set<Permission> userPermissions,
    required String monthYear,
    required int createdBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.payrollRun,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (monthYear.trim().isEmpty) {
      return const Failure(ValidationFailure('Month and year is required.'));
    }

    return _repository.runMonthlyPayroll(
      monthYear: monthYear.trim(),
      createdBy: createdBy,
    );
  }
}

class PaySalaryUseCase {
  final PayrollRepository _repository;
  const PaySalaryUseCase(this._repository);

  Future<Result<void>> call({
    required Set<Permission> userPermissions,
    required int payrollRunId,
    required String paymentMode,
    required int paidBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.payrollRun,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    return _repository.paySalary(
      payrollRunId: payrollRunId,
      paymentMode: paymentMode,
      paidBy: paidBy,
    );
  }
}
