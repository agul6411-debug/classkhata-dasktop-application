import 'package:classkhata/core/security/permission_service.dart';
import 'package:classkhata/core/utils/validators.dart';
import 'package:classkhata/features/reports/domain/entities/report_entities.dart';
import 'package:classkhata/features/reports/domain/repositories/reports_repository.dart';
import 'package:classkhata/features/reports/domain/usecases/export_report_usecases.dart';
import 'package:classkhata/features/reports/domain/usecases/generate_report_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reports Domain & Export Logic', () {
    test('ReportData models rows count and emptiness accurately', () {
      final emptyReport = ReportData(
        type: ReportType.feeCollectionSummary,
        title: 'Fee Collection Summary',
        subtitle: 'Test Subtitle',
        headers: const ['Receipt #', 'Date', 'Amount'],
        rows: const [],
        summaryMetrics: const {},
        generatedAt: DateTime.now(),
      );

      expect(emptyReport.isEmpty, true);
      expect(emptyReport.totalRows, 0);

      final populatedReport = ReportData(
        type: ReportType.defaultersAging,
        title: 'Defaulters Aging',
        subtitle: 'Aging brackets',
        headers: const ['Student', 'Bucket', 'Due'],
        rows: const [
          ['Ali Khan', '0 - 30 Days', 'Rs. 5,000.00'],
          ['Fatima Noor', '61 - 90 Days', 'Rs. 12,000.00'],
        ],
        summaryMetrics: const {'Total Outstanding': 'Rs. 17,000.00'},
        generatedAt: DateTime.now(),
      );

      expect(populatedReport.isEmpty, false);
      expect(populatedReport.totalRows, 2);
    });

    test('GenerateReportUseCase rejects date range where start date is after end date', () async {
      final useCase = GenerateReportUseCase(_MockReportsRepo());
      final filter = ReportFilter(
        reportType: ReportType.feeCollectionSummary,
        startDate: DateTime(2026, 12),
        endDate: DateTime(2026, 10), // Invalid: end before start
      );

      final res = await useCase(
        userPermissions: {Permission.reportsView},
        filter: filter,
      );

      expect(res.isFailure, true);
    });

    test('GenerateReportUseCase enforces reportsView permission', () async {
      final useCase = GenerateReportUseCase(_MockReportsRepo());
      final filter = ReportFilter(
        reportType: ReportType.feeCollectionSummary,
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
      );

      final res = await useCase(
        userPermissions: {Permission.studentsView}, // Missing reportsView
        filter: filter,
      );

      expect(res.isFailure, true);
    });

    test('ExportPdfUseCase and ExportExcelUseCase enforce reportsExport permission', () async {
      final pdfUseCase = ExportPdfUseCase(_MockReportsRepo());
      final excelUseCase = ExportExcelUseCase(_MockReportsRepo());

      final report = ReportData(
        type: ReportType.cashBookStatement,
        title: 'Cash Book',
        subtitle: 'Summary',
        headers: const ['Date', 'Type'],
        rows: const [],
        summaryMetrics: const {},
        generatedAt: DateTime.now(),
      );

      final pdfRes = await pdfUseCase(
        userPermissions: {Permission.reportsView}, // Missing reportsExport
        data: report,
      );
      expect(pdfRes.isFailure, true);

      final excelRes = await excelUseCase(
        userPermissions: {Permission.reportsView}, // Missing reportsExport
        data: report,
      );
      expect(excelRes.isFailure, true);
    });

    test('Excel formula sanitization neutralizes malicious leading characters', () {
      // Dangerous formulas
      expect(sanitizeExcelCell('=SUM(A1:A10)'), "'=SUM(A1:A10)");
      expect(sanitizeExcelCell('+cmd|/c calc'), "'+cmd|/c calc");
      expect(sanitizeExcelCell('-2+3+cmd'), "'-2+3+cmd");
      expect(sanitizeExcelCell('@HYPERLINK("evil.com")'), "'@HYPERLINK(\"evil.com\")");

      // Safe cells
      expect(sanitizeExcelCell('Ali Khan'), 'Ali Khan');
      expect(sanitizeExcelCell('Rs. 5,000.00'), 'Rs. 5,000.00');
      expect(sanitizeExcelCell('REC-0001'), 'REC-0001');
      expect(sanitizeExcelCell(''), '');
    });
  });
}

class _MockReportsRepo implements ReportsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
