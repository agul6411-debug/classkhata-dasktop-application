/// Finance use cases for recording expenses, executing day closing, and P&L summaries.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/finance_entities.dart';
import '../repositories/finance_repository.dart';

class RecordExpenseUseCase {
  const RecordExpenseUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Result<Expense>> call({
    required int categoryId,
    required Money amount,
    required String description,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    if (description.trim().isEmpty) {
      return const Failure(ValidationFailure('Expense description is required.'));
    }
    if (amount.isZero || amount.isNegative) {
      return const Failure(ValidationFailure('Expense amount must be greater than zero.'));
    }

    return _repository.recordExpense(
      categoryId: categoryId,
      amount: amount,
      description: description.trim(),
      paymentMode: paymentMode,
      referenceNumber: referenceNumber?.trim().isEmpty ?? true ? null : referenceNumber!.trim(),
      createdBy: createdBy,
    );
  }
}

class DayClosingUseCase {
  const DayClosingUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Result<DayClosing>> call({
    required DateTime date,
    required Money openingCash,
    required Money actualCash,
    String? discrepancyNote,
    required int closedBy,
  }) async {
    if (openingCash.isNegative || actualCash.isNegative) {
      return const Failure(ValidationFailure('Cash counts cannot be negative.'));
    }

    return _repository.performDayClosing(
      date: date,
      openingCash: openingCash,
      actualCash: actualCash,
      discrepancyNote: discrepancyNote?.trim().isEmpty ?? true ? null : discrepancyNote!.trim(),
      closedBy: closedBy,
    );
  }
}

class ProfitLossUseCase {
  const ProfitLossUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Result<ProfitAndLossSummary>> call({
    required DateTime from,
    required DateTime to,
    required String periodName,
  }) {
    return _repository.getProfitLossSummary(
      from: from,
      to: to,
      periodName: periodName,
    );
  }
}
