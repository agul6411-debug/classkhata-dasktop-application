/// Export use cases for PDF rendering and formula-sanitized Excel.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/report_entities.dart';
import '../repositories/reports_repository.dart';

class ExportPdfUseCase {
  final ReportsRepository _repository;
  const ExportPdfUseCase(this._repository);

  Future<Result<List<int>>> call({
    required Set<Permission> userPermissions,
    required ReportData data,
    String academyName = 'ClassKhata Academy',
    bool isThermal = false,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.reportsExport,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    return _repository.generatePdfBytes(
      data,
      academyName: academyName,
      isThermal: isThermal,
    );
  }
}

class ExportExcelUseCase {
  final ReportsRepository _repository;
  const ExportExcelUseCase(this._repository);

  Future<Result<String>> call({
    required Set<Permission> userPermissions,
    required ReportData data,
    String? targetDirectory,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.reportsExport,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    return _repository.exportToExcel(data, targetDirectory: targetDirectory);
  }
}
