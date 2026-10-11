/// Riverpod providers for Reports & Export feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/security/permission_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/usecases/export_report_usecases.dart';
import '../../domain/usecases/generate_report_usecase.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportsRepositoryImpl(db);
});

final generateReportUseCaseProvider = Provider<GenerateReportUseCase>((ref) {
  return GenerateReportUseCase(ref.watch(reportsRepositoryProvider));
});

final exportPdfUseCaseProvider = Provider<ExportPdfUseCase>((ref) {
  return ExportPdfUseCase(ref.watch(reportsRepositoryProvider));
});

final exportExcelUseCaseProvider = Provider<ExportExcelUseCase>((ref) {
  return ExportExcelUseCase(ref.watch(reportsRepositoryProvider));
});

final selectedReportFilterProvider = StateProvider<ReportFilter>((ref) {
  final now = DateTime.now();
  return ReportFilter(
    reportType: ReportType.feeCollectionSummary,
    startDate: DateTime(now.year, now.month, 1),
    endDate: now,
    monthYear: '${now.year}-${now.month.toString().padLeft(2, '0')}',
  );
});

final activeReportDataProvider = FutureProvider<ReportData>((ref) async {
  final filter = ref.watch(selectedReportFilterProvider);
  final currentUser = ref.watch(authSessionNotifierProvider);
  final useCase = ref.watch(generateReportUseCaseProvider);

  final res = await useCase(
    userPermissions: currentUser?.permissions ?? {Permission.reportsView, Permission.reportsExport},
    filter: filter,
  );

  return res.fold(
    onSuccess: (data) => data,
    onFailure: (f) => throw Exception(f.message),
  );
});
