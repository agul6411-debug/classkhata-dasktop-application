/// Use case for assembling report datasets.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/report_entities.dart';
import '../repositories/reports_repository.dart';

class GenerateReportUseCase {
  final ReportsRepository _repository;
  const GenerateReportUseCase(this._repository);

  Future<Result<ReportData>> call({
    required Set<Permission> userPermissions,
    required ReportFilter filter,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.reportsView,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (filter.startDate.isAfter(filter.endDate)) {
      return const Failure(ValidationFailure('Start date cannot be after end date.'));
    }

    return _repository.buildReport(filter);
  }
}
