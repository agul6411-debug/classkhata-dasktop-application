/// Interactive Reports & Export Screen.
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/report_entities.dart';
import '../providers/reports_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _isExporting = false;
  String? _statusMessage;
  bool _isError = false;

  Future<void> _exportPdf(ReportData data) async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final pdfUseCase = ref.read(exportPdfUseCaseProvider);

    final res = await pdfUseCase(
      userPermissions: currentUser?.permissions ?? {Permission.reportsExport},
      data: data,
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    await res.fold(
      onSuccess: (bytes) async {
        await Printing.layoutPdf(
          onLayout: (_) async => Uint8List.fromList(bytes),
          name: '${data.type.name}_report',
        );
      },
      onFailure: (f) async {
        setState(() {
          _statusMessage = f.message;
          _isError = true;
        });
      },
    );
  }

  Future<void> _exportExcel(ReportData data) async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final excelUseCase = ref.read(exportExcelUseCaseProvider);

    final res = await excelUseCase(
      userPermissions: currentUser?.permissions ?? {Permission.reportsExport},
      data: data,
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    res.fold(
      onSuccess: (filePath) {
        setState(() {
          _statusMessage = 'Excel spreadsheet exported successfully:\n$filePath';
          _isError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $filePath'),
            backgroundColor: Colors.teal.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      },
      onFailure: (f) {
        setState(() {
          _statusMessage = f.message;
          _isError = true;
        });
      },
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final currentFilter = ref.read(selectedReportFilterProvider);
    final initialDate = isStart ? currentFilter.startDate : currentFilter.endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      ref.read(selectedReportFilterProvider.notifier).update(
            (f) => isStart ? f.copyWith(startDate: picked) : f.copyWith(endDate: picked),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(selectedReportFilterProvider);
    final reportDataAsync = ref.watch(activeReportDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports & Statements',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Financial audit reports, aging statements, and formula-sanitized exports.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                reportDataAsync.maybeWhen(
                  data: (data) => Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                        label: const Text('Print / PDF'),
                        onPressed: _isExporting ? null : () => _exportPdf(data),
                      ),
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Export Excel',
                        icon: Icons.table_view,
                        isLoading: _isExporting,
                        onPressed: () => _exportExcel(data),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Controls & Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Report Type Selector
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<ReportType>(
                      value: filter.reportType,
                      decoration: const InputDecoration(labelText: 'Report Type'),
                      isExpanded: true,
                      items: ReportType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(selectedReportFilterProvider.notifier).update((f) => f.copyWith(reportType: val));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Start Date Picker
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          '${filter.startDate.day}/${filter.startDate.month}/${filter.startDate.year}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // End Date Picker
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          '${filter.endDate.day}/${filter.endDate.month}/${filter.endDate.year}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.accent),
                    tooltip: 'Refresh Report',
                    onPressed: () => ref.invalidate(activeReportDataProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status message / Feedback banner
            if (_statusMessage != null) ...[
              if (_isError)
                ErrorBanner(message: _statusMessage!)
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_statusMessage!, style: TextStyle(color: Colors.teal.shade900, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Report Content Area
            Expanded(
              child: reportDataAsync.when(
                data: (data) => _buildReportView(data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error generating report: $err', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(ReportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary KPI Strip
        if (data.summaryMetrics.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: data.summaryMetrics.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.key, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(e.value, style: const TextStyle(color: AppColors.heading, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Table Preview
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: data.rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text('No records matching criteria for ${data.title}.',
                            style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                      columns: data.headers
                          .map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold))))
                          .toList(),
                      rows: data.rows.map((row) {
                        return DataRow(
                          cells: row.map((cell) => DataCell(Text(cell))).toList(),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
