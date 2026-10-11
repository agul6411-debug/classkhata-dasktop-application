/// Finance repository implementation.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/finance_entities.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_dao.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final FinanceDao _dao;
  const FinanceRepositoryImpl(this._dao);

  @override
  Future<Result<List<ExpenseCategory>>> getExpenseCategories() async {
    try {
      final rows = await _dao.getCategories();
      final list = rows.map((r) => ExpenseCategory(
            id: r.id,
            name: r.name,
            description: r.description,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getExpenseCategories error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch expense categories.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<ExpenseCategory>> createExpenseCategory({
    required String name,
    String? description,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertCategory(
        ExpenseCategoriesTableCompanion.insert(
          name: name,
          description: Value(description),
          createdBy: Value(createdBy),
        ),
      );
      return Success(ExpenseCategory(id: id, name: name, description: description));
    } catch (e, st) {
      await AppLogger.instance.error('createExpenseCategory error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create category.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Expense>>> getExpenses({DateTime? from, DateTime? to}) async {
    try {
      final rows = await _dao.getExpenses(from: from, to: to);
      final categories = await _dao.getCategories();
      final catMap = {for (var c in categories) c.id: c.name};

      final list = rows.map((r) => Expense(
            id: r.id,
            categoryId: r.categoryId,
            categoryName: catMap[r.categoryId] ?? 'General',
            amount: Money.fromPaisa(r.amountPaisa),
            description: r.description,
            paymentMode: r.paymentMode,
            referenceNumber: r.referenceNumber,
            expenseDate: r.expenseDate,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getExpenses error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch expenses.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Expense>> recordExpense({
    required int categoryId,
    required Money amount,
    required String description,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    try {
      final res = await _dao.recordExpenseTransaction(
        categoryId: categoryId,
        amountPaisa: amount.paisa,
        description: description,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        createdBy: createdBy,
      );

      return Success(Expense(
        id: res.expense.id,
        categoryId: res.expense.categoryId,
        categoryName: res.categoryName,
        amount: Money.fromPaisa(res.expense.amountPaisa),
        description: res.expense.description,
        paymentMode: res.expense.paymentMode,
        referenceNumber: res.expense.referenceNumber,
        expenseDate: res.expense.expenseDate,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('recordExpense error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not record expense.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<CashBookEntry>>> getCashBookEntries({DateTime? from, DateTime? to}) async {
    try {
      final rows = await _dao.getCashBookEntries(from: from, to: to);
      final list = rows.map((r) => CashBookEntry(
            id: r.id,
            entryType: r.entryType,
            category: r.category,
            amount: Money.fromPaisa(r.amountPaisa),
            description: r.description,
            paymentMode: r.paymentMode,
            entryDate: r.entryDate,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getCashBookEntries error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch cash book entries.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<DayClosing>> performDayClosing({
    required DateTime date,
    required Money openingCash,
    required Money actualCash,
    String? discrepancyNote,
    required int closedBy,
  }) async {
    try {
      final r = await _dao.performDayClosingTransaction(
        date: date,
        openingCashPaisa: openingCash.paisa,
        actualCashPaisa: actualCash.paisa,
        discrepancyNote: discrepancyNote,
        closedBy: closedBy,
      );

      return Success(DayClosing(
        id: r.id,
        closingDate: r.closingDate,
        openingCash: Money.fromPaisa(r.openingCashPaisa),
        totalReceipts: Money.fromPaisa(r.totalReceiptsPaisa),
        totalExpenses: Money.fromPaisa(r.totalExpensesPaisa),
        expectedClosingCash: Money.fromPaisa(r.expectedClosingCashPaisa),
        actualCash: Money.fromPaisa(r.actualCashPaisa),
        discrepancy: Money.fromPaisa(r.discrepancyPaisa),
        discrepancyNote: r.discrepancyNote,
        closedBy: r.closedBy,
        closedAt: r.closedAt,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('performDayClosing error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not execute day closing.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<DayClosing>>> getDayClosings() async {
    try {
      final rows = await _dao.getDayClosings();
      final list = rows.map((r) => DayClosing(
            id: r.id,
            closingDate: r.closingDate,
            openingCash: Money.fromPaisa(r.openingCashPaisa),
            totalReceipts: Money.fromPaisa(r.totalReceiptsPaisa),
            totalExpenses: Money.fromPaisa(r.totalExpensesPaisa),
            expectedClosingCash: Money.fromPaisa(r.expectedClosingCashPaisa),
            actualCash: Money.fromPaisa(r.actualCashPaisa),
            discrepancy: Money.fromPaisa(r.discrepancyPaisa),
            discrepancyNote: r.discrepancyNote,
            closedBy: r.closedBy,
            closedAt: r.closedAt,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getDayClosings error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch day closings.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<ProfitAndLossSummary>> getProfitLossSummary({
    required DateTime from,
    required DateTime to,
    required String periodName,
  }) async {
    try {
      final summary = await _dao.getProfitLossSummary(from: from, to: to, periodName: periodName);
      return Success(summary);
    } catch (e, st) {
      await AppLogger.instance.error('getProfitLossSummary error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not calculate P&L summary.', technicalDetail: e.toString()));
    }
  }
}
