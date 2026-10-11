/// Domain entities and filter models for Reports & Analytics.
library;

import 'package:equatable/equatable.dart';

enum ReportType {
  feeCollectionSummary,
  defaultersAging,
  cashBookStatement,
  profitLossSummary,
  payrollRegister,
  inventoryValuation,
  studentEnrollment;

  String get displayName => switch (this) {
        ReportType.feeCollectionSummary => 'Fee Collection Summary',
        ReportType.defaultersAging => 'Defaulters Aging Report (30/60/90 Days)',
        ReportType.cashBookStatement => 'Cash Book & Transactions',
        ReportType.profitLossSummary => 'Profit & Loss Statement',
        ReportType.payrollRegister => 'Monthly Payroll Register',
        ReportType.inventoryValuation => 'Inventory Stock & Asset Valuation',
        ReportType.studentEnrollment => 'Student Enrollment & Strength',
      };

  String get description => switch (this) {
        ReportType.feeCollectionSummary => 'Aggregated collections by date, batch, and payment mode.',
        ReportType.defaultersAging => 'Unpaid fee vouchers bucketed by 30, 60, and 90+ days overdue.',
        ReportType.cashBookStatement => 'Chronological inflows and outflows with closing balances.',
        ReportType.profitLossSummary => 'Total fee income vs operational expenses with profit margins.',
        ReportType.payrollRegister => 'Staff salary disbursements, allowances, deductions, and advances.',
        ReportType.inventoryValuation => 'On-hand quantities, reorder levels, unit costs, and total values.',
        ReportType.studentEnrollment => 'Complete directory of enrolled students and batch allocations.',
      };
}

class ReportFilter extends Equatable {
  final ReportType reportType;
  final DateTime startDate;
  final DateTime endDate;
  final String? batchFilter;
  final String? monthYear;

  const ReportFilter({
    required this.reportType,
    required this.startDate,
    required this.endDate,
    this.batchFilter,
    this.monthYear,
  });

  ReportFilter copyWith({
    ReportType? reportType,
    DateTime? startDate,
    DateTime? endDate,
    String? batchFilter,
    String? monthYear,
  }) {
    return ReportFilter(
      reportType: reportType ?? this.reportType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      batchFilter: batchFilter ?? this.batchFilter,
      monthYear: monthYear ?? this.monthYear,
    );
  }

  @override
  List<Object?> get props => [reportType, startDate, endDate, batchFilter, monthYear];
}

class ReportData extends Equatable {
  final ReportType type;
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, String> summaryMetrics;
  final DateTime generatedAt;

  const ReportData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    required this.summaryMetrics,
    required this.generatedAt,
  });

  bool get isEmpty => rows.isEmpty;
  int get totalRows => rows.length;

  @override
  List<Object?> get props => [type, title, subtitle, headers, rows, summaryMetrics, generatedAt];
}
