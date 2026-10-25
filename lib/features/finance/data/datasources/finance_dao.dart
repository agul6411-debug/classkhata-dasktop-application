/// Finance DAO providing transactions for expenses, cash book, day closing, and P&L.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/finance_entities.dart';

class FinanceDao {
  const FinanceDao(this._db);
  final AppDatabase _db;

  AppDatabase get db => _db;

  // ---------------------------------------------------------------------------
  // Expense Categories
  // ---------------------------------------------------------------------------

  Future<List<ExpenseCategoriesTableData>> getCategories() =>
      (_db.select(_db.expenseCategoriesTable)..where((t) => t.isActive.equals(true))).get();

  Future<int> insertCategory(ExpenseCategoriesTableCompanion companion) =>
      _db.into(_db.expenseCategoriesTable).insert(companion);

  // ---------------------------------------------------------------------------
  // Expenses & Cash Book Outflow (Atomic Transaction)
  // ---------------------------------------------------------------------------

  Future<({ExpensesTableData expense, String categoryName})> recordExpenseTransaction({
    required int categoryId,
    required int amountPaisa,
    required String description,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      final now = DateTime.now();

      // 1. Insert expense
      final expenseId = await _db.into(_db.expensesTable).insert(
            ExpensesTableCompanion.insert(
              categoryId: categoryId,
              amountPaisa: amountPaisa,
              description: description,
              paymentMode: Value(paymentMode),
              referenceNumber: Value(referenceNumber),
              expenseDate: Value(now),
              createdBy: Value(createdBy),
            ),
          );

      // 2. Insert matching Cash Book Outflow
      await _db.into(_db.cashBookEntriesTable).insert(
            CashBookEntriesTableCompanion.insert(
              entryType: 'outflow',
              category: 'expense',
              amountPaisa: amountPaisa,
              description: description,
              paymentMode: Value(paymentMode),
              referenceId: Value(expenseId),
              entryDate: Value(now),
              createdBy: Value(createdBy),
            ),
          );

      final exp = await (_db.select(_db.expensesTable)..where((t) => t.id.equals(expenseId))).getSingle();
      final cat = await (_db.select(_db.expenseCategoriesTable)..where((t) => t.id.equals(categoryId))).getSingle();

      return (expense: exp, categoryName: cat.name);
    });
  }

  Future<List<ExpensesTableData>> getExpenses({DateTime? from, DateTime? to}) {
    final query = _db.select(_db.expensesTable);
    if (from != null) query.where((t) => t.expenseDate.isBiggerOrEqualValue(from));
    if (to != null) query.where((t) => t.expenseDate.isSmallerOrEqualValue(to));
    query.orderBy([(t) => OrderingTerm.desc(t.expenseDate)]);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Cash Book Entries
  // ---------------------------------------------------------------------------

  Future<List<CashBookEntriesTableData>> getCashBookEntries({DateTime? from, DateTime? to}) {
    final query = _db.select(_db.cashBookEntriesTable);
    if (from != null) query.where((t) => t.entryDate.isBiggerOrEqualValue(from));
    if (to != null) query.where((t) => t.entryDate.isSmallerOrEqualValue(to));
    query.orderBy([(t) => OrderingTerm.desc(t.entryDate)]);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Day Closing Calculation & Transaction
  // ---------------------------------------------------------------------------

  Future<DayClosingsTableData> performDayClosingTransaction({
    required DateTime date,
    required int openingCashPaisa,
    required int actualCashPaisa,
    String? discrepancyNote,
    required int closedBy,
  }) async {
    return _db.transaction(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Check if day is already closed and locked
      final existingClosing = await (_db.select(_db.dayClosingsTable)
            ..where((t) =>
                t.closingDate.isBiggerOrEqualValue(startOfDay) &
                t.closingDate.isSmallerOrEqualValue(endOfDay)))
          .getSingleOrNull();
      if (existingClosing != null) {
        throw StateError('This day has already been closed and locked.');
      }

      // 1. Calculate Day's Cash Receipts (Inflows)
      final inflows = await (_db.select(_db.cashBookEntriesTable)
            ..where((t) =>
                t.entryType.equals('inflow') &
                t.paymentMode.equals('cash') &
                t.category.isNotValue('fee_payment') &
                t.entryDate.isBiggerOrEqualValue(startOfDay) &
                t.entryDate.isSmallerOrEqualValue(endOfDay)))
          .get();

      int totalReceiptsPaisa = 0;
      for (final inf in inflows) {
        totalReceiptsPaisa += inf.amountPaisa;
      }

      // Also account for payments recorded directly today with paymentMode == 'cash'
      final dayPayments = await (_db.select(_db.paymentsTable)
            ..where((t) =>
                t.paymentMode.equals('cash') &
                t.paymentDate.isBiggerOrEqualValue(startOfDay) &
                t.paymentDate.isSmallerOrEqualValue(endOfDay)))
          .get();

      for (final p in dayPayments) {
        totalReceiptsPaisa += p.amountPaisa;
      }

      // 2. Calculate Day's Cash Outflows (Operational expenses, teacher cash salaries, cash supplier payments)
      final outflows = await (_db.select(_db.cashBookEntriesTable)
            ..where((t) =>
                t.entryType.equals('outflow') &
                t.paymentMode.equals('cash') &
                t.entryDate.isBiggerOrEqualValue(startOfDay) &
                t.entryDate.isSmallerOrEqualValue(endOfDay)))
          .get();

      int totalExpensesPaisa = 0;
      for (final out in outflows) {
        totalExpensesPaisa += out.amountPaisa;
      }

      // 3. Expected = Opening + Receipts - Expenses
      final expectedClosingPaisa = openingCashPaisa + totalReceiptsPaisa - totalExpensesPaisa;
      final discrepancyPaisa = actualCashPaisa - expectedClosingPaisa;

      // 4. Save Day Closing Record
      final id = await _db.into(_db.dayClosingsTable).insert(
            DayClosingsTableCompanion.insert(
              closingDate: date,
              openingCashPaisa: openingCashPaisa,
              totalReceiptsPaisa: totalReceiptsPaisa,
              totalExpensesPaisa: totalExpensesPaisa,
              expectedClosingCashPaisa: expectedClosingPaisa,
              actualCashPaisa: actualCashPaisa,
              discrepancyPaisa: Value(discrepancyPaisa),
              discrepancyNote: Value(discrepancyNote),
              closedBy: closedBy,
            ),
          );

      return (_db.select(_db.dayClosingsTable)..where((t) => t.id.equals(id))).getSingle();
    });
  }

  Future<List<DayClosingsTableData>> getDayClosings() =>
      (_db.select(_db.dayClosingsTable)..orderBy([(t) => OrderingTerm.desc(t.closingDate)])).get();

  // ---------------------------------------------------------------------------
  // Profit & Loss Summary
  // ---------------------------------------------------------------------------

  Future<ProfitAndLossSummary> getProfitLossSummary({
    required DateTime from,
    required DateTime to,
    required String periodName,
  }) async {
    // 1. Fee Income from Payments
    final feePayments = await (_db.select(_db.paymentsTable)
          ..where((t) => t.paymentDate.isBiggerOrEqualValue(from) & t.paymentDate.isSmallerOrEqualValue(to)))
        .get();

    int feeIncomePaisa = 0;
    for (final p in feePayments) {
      feeIncomePaisa += p.amountPaisa;
    }

    // 2. Other Inflows from Cash Book
    final otherInflows = await (_db.select(_db.cashBookEntriesTable)
          ..where((t) =>
              t.entryType.equals('inflow') &
              t.category.isNotValue('fee_payment') &
              t.entryDate.isBiggerOrEqualValue(from) &
              t.entryDate.isSmallerOrEqualValue(to)))
        .get();

    int otherIncomePaisa = 0;
    for (final inf in otherInflows) {
      otherIncomePaisa += inf.amountPaisa;
    }

    final totalIncomePaisa = feeIncomePaisa + otherIncomePaisa;

    // 3. Total Expenses (unifying operational expenses, payroll/salaries, and inventory purchases)
    final outflows = await (_db.select(_db.cashBookEntriesTable)
          ..where((t) =>
              t.entryType.equals('outflow') &
              t.entryDate.isBiggerOrEqualValue(from) &
              t.entryDate.isSmallerOrEqualValue(to)))
        .get();

    int totalExpensesPaisa = 0;
    for (final exp in outflows) {
      totalExpensesPaisa += exp.amountPaisa;
    }

    final netProfitPaisa = totalIncomePaisa - totalExpensesPaisa;
    final margin = totalIncomePaisa > 0 ? (netProfitPaisa / totalIncomePaisa) * 100 : 0.0;

    return ProfitAndLossSummary(
      period: periodName,
      totalIncome: Money.fromPaisa(totalIncomePaisa),
      feeIncome: Money.fromPaisa(feeIncomePaisa),
      totalExpenses: Money.fromPaisa(totalExpensesPaisa),
      netProfit: Money.fromPaisa(netProfitPaisa),
      marginPercentage: margin,
    );
  }
}
