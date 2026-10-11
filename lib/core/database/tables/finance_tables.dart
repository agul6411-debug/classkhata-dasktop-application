/// Drift table definitions for Finance & Cash Book.
///
/// Rules:
///   - All money is stored as INTEGER (paisa).
///   - Financial entries are append-only.
///   - Day closings audit cash discrepancies.
library;

import 'package:drift/drift.dart';
import 'core_tables.dart';

// ---------------------------------------------------------------------------
// Expense Categories
// ---------------------------------------------------------------------------

class ExpenseCategoriesTable extends Table {
  @override
  String get tableName => 'expense_categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g. "Rent", "Utilities", "Supplies"
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

class ExpensesTable extends Table {
  @override
  String get tableName => 'expenses';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(ExpenseCategoriesTable, #id)();
  IntColumn get amountPaisa => integer()();
  TextColumn get description => text()();
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  TextColumn get referenceNumber => text().nullable()();
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('expensesCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
  
  // Reversal fields
  DateTimeColumn get reversedAt => dateTime().nullable()();
  @ReferenceName('expensesReversed')
  IntColumn get reversedBy => integer().nullable().references(UsersTable, #id)();
  TextColumn get reversalReason => text().nullable()();
}

// ---------------------------------------------------------------------------
// Cash Book Entries
// ---------------------------------------------------------------------------

class CashBookEntriesTable extends Table {
  @override
  String get tableName => 'cash_book_entries';

  IntColumn get id => integer().autoIncrement()();
  /// 'inflow' or 'outflow'
  TextColumn get entryType => text()();
  /// 'fee_payment', 'expense', 'salary', 'other'
  TextColumn get category => text()();
  IntColumn get amountPaisa => integer()();
  TextColumn get description => text()();
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  IntColumn get referenceId => integer().nullable()(); // ID of payment or expense
  DateTimeColumn get entryDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Day Closings
// ---------------------------------------------------------------------------

class DayClosingsTable extends Table {
  @override
  String get tableName => 'day_closings';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get closingDate => dateTime()();
  IntColumn get openingCashPaisa => integer()();
  IntColumn get totalReceiptsPaisa => integer()();
  IntColumn get totalExpensesPaisa => integer()();
  IntColumn get expectedClosingCashPaisa => integer()();
  IntColumn get actualCashPaisa => integer()();
  IntColumn get discrepancyPaisa => integer().withDefault(const Constant(0))();
  TextColumn get discrepancyNote => text().nullable()();
  IntColumn get closedBy => integer().references(UsersTable, #id)();
  DateTimeColumn get closedAt => dateTime().withDefault(currentDateAndTime)();
}
