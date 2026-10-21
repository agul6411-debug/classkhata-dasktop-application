/// Interactive Reports & Export Screen.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
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
  String? _lastExportedFilePath;
  bool _isError = false;

  String _selectedCategory = 'All';
  String _selectedDatePreset = 'This Month';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  static const List<String> _categories = [
    'All',
    'Financial & Accounts',
    'Students & Fees',
    'Staff & Payroll',
    'Inventory & Store',
    'Security & Audit',
  ];

  static const List<String> _datePresets = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'This Year',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month);
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        start = lastMonth;
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'This Year':
        start = DateTime(now.year);
        break;
      default:
        return;
    }

    setState(() => _selectedDatePreset = preset);
    ref.read(selectedReportFilterProvider.notifier).update(
          (f) => f.copyWith(
            startDate: start,
            endDate: end,
            monthYear: () => '${start.year}-${start.month.toString().padLeft(2, '0')}',
          ),
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
      setState(() => _selectedDatePreset = 'Custom');
      ref.read(selectedReportFilterProvider.notifier).update((f) {
        final newStart = isStart ? picked : f.startDate;
        final newEnd = !isStart ? picked : f.endDate;
        return f.copyWith(
          startDate: newStart,
          endDate: newEnd,
          monthYear: () => '${newStart.year}-${newStart.month.toString().padLeft(2, '0')}',
        );
      });
    }
  }

  Future<void> _exportPdf(ReportData data, {bool isThermal = false}) async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
      _lastExportedFilePath = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final academy = ref.read(academyProfileProvider).valueOrNull;
    final pdfUseCase = ref.read(exportPdfUseCaseProvider);

    final res = await pdfUseCase(
      userPermissions: currentUser?.permissions ?? {Permission.reportsExport},
      data: data,
      academyName: academy?.name ?? 'ClassKhata Academy',
      isThermal: isThermal,
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    await res.fold(
      onSuccess: (bytes) async {
        PdfPrintPreviewDialog.show(
          context,
          title: '${data.title} (${isThermal ? "Thermal Roll" : "A4"} Preview)',
          initialFormat: isThermal ? PdfPageFormat.roll80 : PdfPageFormat.a4.landscape,
          pdfFileName: '${data.type.name}_${isThermal ? 'thermal' : 'a4'}.pdf',
          buildPdf: (_) async => Uint8List.fromList(bytes),
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
      _lastExportedFilePath = null;
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
          _statusMessage = 'Excel spreadsheet exported successfully!';
          _lastExportedFilePath = filePath;
          _isError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Excel exported: $filePath')),
                TextButton(
                  onPressed: () => _openFileInExplorer(filePath),
                  child: const Text('OPEN FOLDER', style: TextStyle(color: Colors.yellowAccent)),
                ),
              ],
            ),
            backgroundColor: Colors.teal.shade800,
            duration: const Duration(seconds: 8),
          ),
        );
      },
      onFailure: (f) {
        setState(() {
          _statusMessage = f.message;
          _lastExportedFilePath = null;
          _isError = true;
        });
      },
    );
  }

  Future<void> _openFileInExplorer(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(selectedReportFilterProvider);
    final reportDataAsync = ref.watch(activeReportDataProvider);
    final academicData = ref.watch(academicDataProvider).valueOrNull;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    // Filter available report types based on selected category
    final availableReportTypes = ReportType.values.where((t) {
      if (_selectedCategory == 'All') return true;
      return t.category == _selectedCategory;
    }).toList();

    final dateFormat = DateFormat('dd/MM/yyyy');

    // Does this report support class / batch filtering?
    final supportsBatchFilter = filter.reportType == ReportType.feeCollectionSummary ||
        filter.reportType == ReportType.defaultersAging ||
        filter.reportType == ReportType.batchWiseFees ||
        filter.reportType == ReportType.studentEnrollment;

    final courseMap = academicData != null
        ? {for (final c in academicData.courses) c.id: c.name}
        : <int, String>{};

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assessment_rounded, size: 26, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Text(
                            'Reports & Analytics',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: headingColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Financial audit logs, student fee registers, store valuation & formula-sanitized exports.',
                        style: TextStyle(color: textMutedColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                reportDataAsync.maybeWhen(
                  data: (data) => Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                        label: const Text('Print A4 (PDF)'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.redAccent.shade100),
                          foregroundColor: isDark ? Colors.red.shade300 : Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: _isExporting ? null : () => _exportPdf(data),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16, color: AppColors.accentLight),
                        label: const Text('Thermal (80mm)'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent.withValues(alpha: 0.4)),
                          foregroundColor: isDark ? AppColors.accentLight : AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: _isExporting ? null : () => _exportPdf(data, isThermal: true),
                      ),
                      const SizedBox(width: 10),
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

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.accent.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.accent : textMutedColor,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                          // If current report type is not in selected category, switch to the first one in that category
                          final catTypes = ReportType.values.where((t) {
                            if (cat == 'All') return true;
                            return t.category == cat;
                          }).toList();
                          if (catTypes.isNotEmpty && !catTypes.contains(filter.reportType)) {
                            ref.read(selectedReportFilterProvider.notifier).update(
                                  (f) => f.copyWith(reportType: catTypes.first),
                                );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Controls & Filters Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Report Type, Date Pickers, Batch Filter
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Report Type Dropdown
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<ReportType>(
                          value: availableReportTypes.contains(filter.reportType)
                              ? filter.reportType
                              : availableReportTypes.firstOrNull,
                          decoration: InputDecoration(
                            labelText: 'Report Type',
                            isDense: true,
                            prefixIcon: const Icon(Icons.insert_chart_outlined, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          isExpanded: true,
                          items: availableReportTypes.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.displayName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(selectedReportFilterProvider.notifier).update((f) => f.copyWith(reportType: val));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // From Date
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'From Date',
                              isDense: true,
                              prefixIcon: const Icon(Icons.calendar_today, size: 16),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              dateFormat.format(filter.startDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // To Date
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _pickDate(isStart: false),
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'To Date',
                              isDense: true,
                              prefixIcon: const Icon(Icons.event, size: 16),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              dateFormat.format(filter.endDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Optional Batch/Section filter
                      if (supportsBatchFilter && academicData != null) ...[
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            value: filter.batchFilter,
                            decoration: InputDecoration(
                              labelText: 'Class / Section Filter',
                              isDense: true,
                              prefixIcon: const Icon(Icons.class_outlined, size: 16),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(child: Text('All Classes & Sections', style: TextStyle(fontSize: 12))),
                              ...academicData.batches.map(
                                (b) {
                                  final cName = courseMap[b.courseId];
                                  final label = cName != null ? '$cName - ${b.name}' : b.name;
                                  return DropdownMenuItem(
                                    value: b.id.toString(),
                                    child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                  );
                                },
                              ),
                            ],
                            onChanged: (val) {
                              ref.read(selectedReportFilterProvider.notifier).update(
                                    (f) => f.copyWith(batchFilter: () => val),
                                  );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.accent),
                        tooltip: 'Refresh Report Data',
                        onPressed: () => ref.invalidate(activeReportDataProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Quick Presets & In-Table Live Search
                  Row(
                    children: [
                      // Quick Date Presets
                      Text('Period: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMutedColor)),
                      const SizedBox(width: 6),
                      ..._datePresets.map((preset) {
                        final isSelected = _selectedDatePreset == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _applyDatePreset(preset),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkCardSub : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : borderColor,
                                  width: isSelected ? 1.2 : 0.8,
                                ),
                              ),
                              child: Text(
                                preset,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.accent : headingColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),

                      // In-table live search box
                      SizedBox(
                        width: 280,
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Filter loaded rows...',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 16),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Status message / Export notification banner
            if (_statusMessage != null) ...[
              if (_isError)
                ErrorBanner(message: _statusMessage!)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.teal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lastExportedFilePath != null
                              ? '$_statusMessage\nPath: $_lastExportedFilePath'
                              : _statusMessage!,
                          style: TextStyle(color: Colors.teal.shade900, fontSize: 13),
                        ),
                      ),
                      if (_lastExportedFilePath != null)
                        TextButton.icon(
                          icon: const Icon(Icons.folder_open, size: 16, color: Colors.teal),
                          label: const Text('Open in Explorer', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          onPressed: () => _openFileInExplorer(_lastExportedFilePath!),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.teal),
                        onPressed: () => setState(() {
                          _statusMessage = null;
                          _lastExportedFilePath = null;
                        }),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Main Report Display Area
            Expanded(
              child: reportDataAsync.when(
                data: (data) => _buildReportView(
                  data,
                  isDark,
                  surfaceColor,
                  borderColor,
                  headingColor,
                  textMutedColor,
                ),
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Generating report data...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                error: (err, _) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Error generating report',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                        ),
                        const SizedBox(height: 4),
                        Text(err.toString(), style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Try Again'),
                          onPressed: () => ref.invalidate(activeReportDataProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(
    ReportData data,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color headingColor,
    Color textMutedColor,
  ) {
    // Filter rows based on live search
    final filteredRows = _searchQuery.isEmpty
        ? data.rows
        : data.rows.where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary KPI Metric Cards
        if (data.summaryMetrics.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: data.summaryMetrics.entries.map((e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 160),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value,
                      style: TextStyle(
                        color: headingColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // Table Header Info Strip: Showing X records
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  data.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: headingColor),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _searchQuery.isEmpty
                        ? '${data.rows.length} records'
                        : '${filteredRows.length} of ${data.rows.length} records',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            Text(
              data.subtitle,
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Dual-Axis Scrollable DataTable Container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: filteredRows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long_outlined,
                          size: 48,
                          color: textMutedColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No records match search "$_searchQuery"'
                              : 'No records found for ${data.title} in the selected period.',
                          style: TextStyle(color: textMutedColor, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _searchController.clear(),
                            child: const Text('Clear Search Filter'),
                          ),
                        ],
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Scrollbar(
                        controller: _verticalScrollController,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            notificationPredicate: (notif) => notif.depth == 1,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowHeight: 44,
                                  dataRowMinHeight: 42,
                                  dataRowMaxHeight: 52,
                                  horizontalMargin: 16,
                                  columnSpacing: 24,
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? AppColors.darkCardSub : Colors.grey.shade100,
                                  ),
                                  columns: data.headers.map((h) {
                                    return DataColumn(
                                      label: Text(
                                        h,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: headingColor,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  rows: filteredRows.map((row) {
                                    return DataRow(
                                      cells: row.map((cell) {
                                        return DataCell(
                                          Text(
                                            cell,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
