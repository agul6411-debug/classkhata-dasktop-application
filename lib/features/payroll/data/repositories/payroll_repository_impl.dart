/// Payroll repository implementation.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/payroll_entities.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../datasources/payroll_dao.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  final PayrollDao _dao;
  const PayrollRepositoryImpl(this._dao);

  @override
  Future<Result<List<StaffMember>>> getStaffMembers({StaffStatus? status}) async {
    try {
      final rows = await _dao.getStaffMembers(status: status);
      final list = rows.map((r) => StaffMember(
            id: r.id,
            staffCode: r.staffCode,
            name: r.name,
            phone: r.phone,
            designation: r.designation,
            cnic: r.cnic,
            joiningDate: r.joiningDate,
            status: StaffStatus.fromString(r.status),
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getStaffMembers error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch staff members.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<StaffMember>> createStaffMember({
    required String name,
    required String phone,
    required String designation,
    String? cnic,
    required int createdBy,
  }) async {
    try {
      final code = await _dao.getNextStaffCode();
      final id = await _dao.insertStaff(
        StaffMembersTableCompanion.insert(
          staffCode: code,
          name: name,
          phone: phone,
          designation: designation,
          cnic: Value(cnic),
          createdBy: Value(createdBy),
        ),
      );
      return Success(StaffMember(
        id: id,
        staffCode: code,
        name: name,
        phone: phone,
        designation: designation,
        cnic: cnic,
        joiningDate: DateTime.now(),
        status: StaffStatus.active,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createStaffMember error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not register staff member.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<SalaryStructure?>> getSalaryStructure(int staffId) async {
    try {
      final row = await _dao.getSalaryStructure(staffId);
      if (row == null) return const Success(null);

      return Success(SalaryStructure(
        id: row.id,
        staffId: row.staffId,
        structureType: row.structureType,
        baseAmount: Money.fromPaisa(row.baseAmountPaisa),
        allowances: Money.fromPaisa(row.allowancesPaisa),
        deductions: Money.fromPaisa(row.deductionsPaisa),
        isActive: row.isActive,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('getSalaryStructure error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch salary structure.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> setSalaryStructure({
    required int staffId,
    required String structureType,
    required Money baseAmount,
    required Money allowances,
    required Money deductions,
    required int createdBy,
  }) async {
    try {
      await _dao.setSalaryStructure(
        SalaryStructuresTableCompanion.insert(
          staffId: staffId,
          structureType: Value(structureType),
          baseAmountPaisa: Value(baseAmount.paisa),
          allowancesPaisa: Value(allowances.paisa),
          deductionsPaisa: Value(deductions.paisa),
          createdBy: Value(createdBy),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('setSalaryStructure error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not update salary structure.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<PayrollRun>>> getPayrollRuns({String? monthYear}) async {
    try {
      final rows = await _dao.getPayrollRuns(monthYear: monthYear);
      final staffList = await _dao.getStaffMembers();
      final staffMap = {for (var s in staffList) s.id: s};

      final list = rows.map((r) {
        final staff = staffMap[r.staffId];
        return PayrollRun(
          id: r.id,
          monthYear: r.monthYear,
          staffId: r.staffId,
          staffName: staff?.name ?? 'Staff #${r.staffId}',
          designation: staff?.designation ?? 'N/A',
          baseSalary: Money.fromPaisa(r.baseSalaryPaisa),
          allowances: Money.fromPaisa(r.allowancesPaisa),
          deductions: Money.fromPaisa(r.deductionsPaisa),
          advanceRecovery: Money.fromPaisa(r.advanceRecoveryPaisa),
          netSalary: Money.fromPaisa(r.netSalaryPaisa),
          status: r.status,
          paidAt: r.paidAt,
          paymentMode: r.paymentMode,
        );
      }).toList();

      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getPayrollRuns error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch payroll runs.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<int>> runMonthlyPayroll({
    required String monthYear,
    required int createdBy,
  }) async {
    try {
      final count = await _dao.runMonthlyPayrollTransaction(
        monthYear: monthYear,
        createdBy: createdBy,
      );
      return Success(count);
    } catch (e, st) {
      await AppLogger.instance.error('runMonthlyPayroll error', error: e, stack: st);
      return Failure(DatabaseFailure('Payroll run execution failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> paySalary({
    required int payrollRunId,
    required String paymentMode,
    required int paidBy,
  }) async {
    try {
      await _dao.paySalaryTransaction(
        payrollRunId: payrollRunId,
        paymentMode: paymentMode,
        paidBy: paidBy,
      );
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('paySalary error', error: e, stack: st);
      return Failure(DatabaseFailure('Salary disbursement failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<StaffAdvance>>> getStaffAdvances({int? staffId}) async {
    try {
      final rows = await _dao.getStaffAdvances(staffId: staffId);
      final list = rows.map((r) => StaffAdvance(
            id: r.id,
            staffId: r.staffId,
            amount: Money.fromPaisa(r.amountPaisa),
            recovered: Money.fromPaisa(r.recoveredPaisa),
            remaining: Money.fromPaisa(r.remainingPaisa),
            reason: r.reason,
            issueDate: r.issueDate,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getStaffAdvances error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch staff advances.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<StaffAdvance>> issueAdvance({
    required int staffId,
    required Money amount,
    String? reason,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertAdvance(
        StaffAdvancesTableCompanion.insert(
          staffId: staffId,
          amountPaisa: amount.paisa,
          remainingPaisa: amount.paisa,
          reason: Value(reason),
          createdBy: Value(createdBy),
        ),
      );
      return Success(StaffAdvance(
        id: id,
        staffId: staffId,
        amount: amount,
        recovered: const Money(0),
        remaining: amount,
        reason: reason,
        issueDate: DateTime.now(),
      ));
    } catch (e, st) {
      await AppLogger.instance.error('issueAdvance error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not record advance.', technicalDetail: e.toString()));
    }
  }
}
