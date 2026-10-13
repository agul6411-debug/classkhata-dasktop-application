/// Riverpod providers for Executive Dashboard.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../fees/presentation/providers/fee_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../domain/entities/dashboard_kpis.dart';
import '../../domain/usecases/get_dashboard_kpis_usecase.dart';

final selectedDashboardMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

final dashboardKpisUseCaseProvider = Provider<GetDashboardKpisUseCase>((ref) {
  return GetDashboardKpisUseCase(
    feeRepo: ref.watch(feeRepositoryProvider),
    studentRepo: ref.watch(studentRepositoryProvider),
    academicRepo: ref.watch(academicRepositoryProvider),
  );
});

final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  final month = ref.watch(selectedDashboardMonthProvider);
  final useCase = ref.watch(dashboardKpisUseCaseProvider);

  // Automatically recompute KPIs when students or academic entities change
  ref.watch(studentListVersionProvider);
  ref.watch(academicDataProvider);

  final result = await useCase(month);
  return result.fold(
    onSuccess: (kpis) => kpis,
    onFailure: (f) => throw Exception(f.message),
  );
});
