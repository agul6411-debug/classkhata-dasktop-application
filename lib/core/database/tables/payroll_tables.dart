/// Drift table definitions for Payroll management.
///
/// Rules:
///   - All money is stored as INTEGER (paisa).
///   - Allowances, deductions, advances, and net salaries are strictly integer.
library;

import 'package:drift/drift.dart';
import 'core_tables.dart';

// ---------------------------------------------------------------------------
// Staff Members
// ---------------------------------------------------------------------------

class StaffMembersTable extends Table {
  @override
  String get tableName => 'staff_members';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get staffCode => text().unique()(); // e.g. "STF-0001"
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().withLength(min: 1, max: 50)();
  TextColumn get designation => text().withLength(min: 1, max: 100)(); // e.g. "Senior Teacher", "Accountant"
  TextColumn get cnic => text().nullable()();
  DateTimeColumn get joiningDate => dateTime().withDefault(currentDateAndTime)();
  /// 'active', 'inactive', 'resigned'
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('staffCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Salary Structures
// ---------------------------------------------------------------------------

class SalaryStructuresTable extends Table {
  @override
  String get tableName => 'salary_structures';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(StaffMembersTable, #id)();
  /// 'fixed', 'per_class', 'per_hour'
  TextColumn get structureType => text().withDefault(const Constant('fixed'))();
  IntColumn get baseAmountPaisa => integer().withDefault(const Constant(0))();
  IntColumn get allowancesPaisa => integer().withDefault(const Constant(0))();
  IntColumn get deductionsPaisa => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('salaryStructuresCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Monthly Payroll Runs
// ---------------------------------------------------------------------------

class PayrollRunsTable extends Table {
  @override
  String get tableName => 'payroll_runs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get monthYear => text()(); // e.g. "2026-10"
  IntColumn get staffId => integer().references(StaffMembersTable, #id)();
  IntColumn get baseSalaryPaisa => integer()();
  IntColumn get allowancesPaisa => integer().withDefault(const Constant(0))();
  IntColumn get deductionsPaisa => integer().withDefault(const Constant(0))();
  IntColumn get advanceRecoveryPaisa => integer().withDefault(const Constant(0))();
  IntColumn get netSalaryPaisa => integer()();
  /// 'unpaid', 'paid'
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get paymentMode => text().nullable()(); // 'cash', 'bank'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('payrollRunsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Staff Advances
// ---------------------------------------------------------------------------

class StaffAdvancesTable extends Table {
  @override
  String get tableName => 'staff_advances';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get staffId => integer().references(StaffMembersTable, #id)();
  IntColumn get amountPaisa => integer()();
  IntColumn get recoveredPaisa => integer().withDefault(const Constant(0))();
  IntColumn get remainingPaisa => integer()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get issueDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('staffAdvancesCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}
