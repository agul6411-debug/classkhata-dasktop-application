/// Abstract repository for Finance management.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/finance_entities.dart';

abstract interface class FinanceRepository {
  // Expense Categories
  Future<Result<List<ExpenseCategory>>> getExpenseCategories();
  Future<Result<ExpenseCategory>> createExpenseCategory({
    required String name,
    String? description,
    required int createdBy,
  });

  // Expenses
  Future<Result<List<Expense>>> getExpenses({DateTime? from, DateTime? to});
  Future<Result<Expense>> recordExpense({
    required int categoryId,
    required Money amount,
    required String description,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  });

  // Cash Book
  Future<Result<List<CashBookEntry>>> getCashBookEntries({DateTime? from, DateTime? to});

  // Day Closing
  Future<Result<DayClosing>> performDayClosing({
    required DateTime date,
    required Money openingCash,
    required Money actualCash,
    String? discrepancyNote,
    required int closedBy,
  });
  Future<Result<List<DayClosing>>> getDayClosings();

  // P&L Summary
  Future<Result<ProfitAndLossSummary>> getProfitLossSummary({
    required DateTime from,
    required DateTime to,
    required String periodName,
  });
}
