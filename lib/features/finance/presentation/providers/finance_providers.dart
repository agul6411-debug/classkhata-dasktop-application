/// Riverpod providers for Finance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/finance_dao.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/finance_entities.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/usecases/finance_usecases.dart';

final financeDaoProvider = Provider<FinanceDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FinanceDao(db);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return FinanceRepositoryImpl(dao);
});

final recordExpenseUseCaseProvider = Provider<RecordExpenseUseCase>((ref) {
  return RecordExpenseUseCase(ref.watch(financeRepositoryProvider));
});

final dayClosingUseCaseProvider = Provider<DayClosingUseCase>((ref) {
  return DayClosingUseCase(ref.watch(financeRepositoryProvider));
});

final profitLossUseCaseProvider = Provider<ProfitLossUseCase>((ref) {
  return ProfitLossUseCase(ref.watch(financeRepositoryProvider));
});

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final res = await repo.getExpenseCategories();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final expensesListProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final res = await repo.getExpenses();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final dayClosingsListProvider = FutureProvider<List<DayClosing>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final res = await repo.getDayClosings();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});
