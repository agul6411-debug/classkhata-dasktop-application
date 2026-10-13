/// Drift table definitions for Fee Management.
///
/// Rules:
///   - All money is stored as INTEGER (paisa).
///   - Financial entries are append-only; reversals include reason and user.
///   - Receipt numbers are sequential and gap-free via atomic counters.
library;

import 'package:drift/drift.dart';

import 'academic_tables.dart';
import 'core_tables.dart';

// ---------------------------------------------------------------------------
// Fee Structures (per Batch or Course)
// ---------------------------------------------------------------------------

class FeeStructuresTable extends Table {
  @override
  String get tableName => 'fee_structures';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().references(BatchesTable, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g. "Tuition Fee"
  IntColumn get amountPaisa => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Receipt Counters (Guarantees Gap-Free Sequential Receipt Numbers)
// ---------------------------------------------------------------------------

class ReceiptCountersTable extends Table {
  @override
  String get tableName => 'receipt_counters';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get series => text().withLength(min: 1, max: 20)(); // e.g. "RCP"
  IntColumn get currentNumber => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// Fee Vouchers (Monthly bills per student)
// ---------------------------------------------------------------------------

class FeeVouchersTable extends Table {
  @override
  String get tableName => 'fee_vouchers';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get voucherNumber => text().unique()(); // e.g. "VCH-202610-0001"
  IntColumn get studentId => integer().references(StudentsTable, #id)();
  IntColumn get batchId => integer().references(BatchesTable, #id)();
  TextColumn get monthYear => text()(); // e.g. "2026-10"
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  
  // Amounts stored in integer paisa
  IntColumn get baseAmountPaisa => integer().withDefault(const Constant(0))();
  IntColumn get discountPaisa => integer().withDefault(const Constant(0))();
  IntColumn get lateFeePaisa => integer().withDefault(const Constant(0))();
  IntColumn get carryForwardPaisa => integer().withDefault(const Constant(0))();
  IntColumn get totalDuePaisa => integer().withDefault(const Constant(0))();
  IntColumn get amountPaidPaisa => integer().withDefault(const Constant(0))();
  
  /// Status: 'unpaid', 'partial', 'paid', 'overdue', 'cancelled'
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('vouchersCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
  
  // Reversal fields
  DateTimeColumn get reversedAt => dateTime().nullable()();
  @ReferenceName('vouchersReversed')
  IntColumn get reversedBy => integer().nullable().references(UsersTable, #id)();
  TextColumn get reversalReason => text().nullable()();
}

// ---------------------------------------------------------------------------
// Receipts (Gap-free sequential receipts)
// ---------------------------------------------------------------------------

class ReceiptsTable extends Table {
  @override
  String get tableName => 'receipts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get receiptNumber => text().unique()(); // e.g. "RCP-000001"
  IntColumn get voucherId => integer().references(FeeVouchersTable, #id)();
  IntColumn get studentId => integer().references(StudentsTable, #id)();
  IntColumn get amountPaisa => integer()();
  TextColumn get qrData => text()(); // verification payload
  DateTimeColumn get receiptDate => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  @ReferenceName('receiptsCancelled')
  IntColumn get cancelledBy => integer().nullable().references(UsersTable, #id)();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('receiptsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Payments (Append-only ledger entries)
// ---------------------------------------------------------------------------

class PaymentsTable extends Table {
  @override
  String get tableName => 'payments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get voucherId => integer().references(FeeVouchersTable, #id)();
  IntColumn get studentId => integer().references(StudentsTable, #id)();
  IntColumn get receiptId => integer().references(ReceiptsTable, #id)();
  IntColumn get amountPaisa => integer()();
  
  /// Payment mode: 'cash', 'bank', 'online'
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  TextColumn get referenceNumber => text().nullable()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('paymentsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
  
  // Reversal
  DateTimeColumn get reversedAt => dateTime().nullable()();
  @ReferenceName('paymentsReversed')
  IntColumn get reversedBy => integer().nullable().references(UsersTable, #id)();
  TextColumn get reversalReason => text().nullable()();
}
