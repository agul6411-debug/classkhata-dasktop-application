/// Abstract repository interface for Report generation and export.
library;

import '../../../../core/errors/failures.dart';
import '../entities/report_entities.dart';

abstract interface class ReportsRepository {
  /// Builds the structured in-memory [ReportData] based on given filters.
  Future<Result<ReportData>> buildReport(ReportFilter filter);

  /// Generates printable PDF document bytes (A4 Landscape or 80mm Thermal slip).
  Future<Result<List<int>>> generatePdfBytes(
    ReportData data, {
    String academyName,
    bool isThermal,
  });

  /// Exports sanitized Excel file to disk and returns the written file path.
  Future<Result<String>> exportToExcel(ReportData data, {String? targetDirectory});
}
