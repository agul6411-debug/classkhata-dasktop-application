/// Riverpod providers for Payroll management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/payroll_dao.dart';
import '../../data/repositories/payroll_repository_impl.dart';
import '../../domain/entities/payroll_entities.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../../domain/usecases/payroll_usecases.dart';

final payrollDaoProvider = Provider<PayrollDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PayrollDao(db);
});

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  final dao = ref.watch(payrollDaoProvider);
  return PayrollRepositoryImpl(dao);
});

final createStaffMemberUseCaseProvider = Provider<CreateStaffMemberUseCase>((ref) {
  return CreateStaffMemberUseCase(ref.watch(payrollRepositoryProvider));
});

final runMonthlyPayrollUseCaseProvider = Provider<RunMonthlyPayrollUseCase>((ref) {
  return RunMonthlyPayrollUseCase(ref.watch(payrollRepositoryProvider));
});

final paySalaryUseCaseProvider = Provider<PaySalaryUseCase>((ref) {
  return PaySalaryUseCase(ref.watch(payrollRepositoryProvider));
});

final staffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  final repo = ref.watch(payrollRepositoryProvider);
  final res = await repo.getStaffMembers();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final selectedPayrollMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

final payrollRunsListProvider = FutureProvider<List<PayrollRun>>((ref) async {
  final month = ref.watch(selectedPayrollMonthProvider);
  final repo = ref.watch(payrollRepositoryProvider);
  final res = await repo.getPayrollRuns(monthYear: month);
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final staffAdvancesListProvider = FutureProvider<List<StaffAdvance>>((ref) async {
  final repo = ref.watch(payrollRepositoryProvider);
  final res = await repo.getStaffAdvances();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});
