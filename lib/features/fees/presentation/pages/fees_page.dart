/// Main Fees Management Page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../students/domain/entities/student_entities.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../domain/entities/fee_entities.dart';
import '../providers/fee_providers.dart';
import '../widgets/fee_collection_wizard.dart';
import '../widgets/voucher_generate_dialog.dart';

class FeesPage extends ConsumerStatefulWidget {
  const FeesPage({super.key});

  @override
  ConsumerState<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends ConsumerState<FeesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Fee Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vouchers, 3-step fee collection, receipts, and 30/60/90 days aging.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('Generate Vouchers'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const VoucherGenerateDialog(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Collect Fee',
                      icon: Icons.payments,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const FeeCollectionWizard(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Vouchers & Ledger'),
                  Tab(text: 'Defaulter Aging (30/60/90d)'),
                  Tab(text: 'Approvals & Adjustments'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVouchersTab(),
                  _buildDefaulterAgingTab(),
                  _buildApprovalsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Vouchers & Ledger
  // ---------------------------------------------------------------------------

  Future<void> _previewVoucher(FeeVoucher voucher) async {
    final academy = ref.read(academyProfileProvider).valueOrNull;
    final academicData = ref.read(academicDataProvider).valueOrNull;
    final batch = academicData?.batches.where((b) => b.id == voucher.batchId).firstOrNull;
    final batchName = batch?.name ?? 'Class / Batch';

    // Fetch student info
    final studentRepo = ref.read(studentRepositoryProvider);
    final studentRes = await studentRepo.getStudentById(voucher.studentId);
    final student = studentRes.fold(onSuccess: (s) => s, onFailure: (_) => null);
    final studentName = student?.name ?? 'Student #${voucher.studentId}';
    final rollNumber = student?.rollNumber;

    if (!mounted) return;

    PdfPrintPreviewDialog.show(
      context,
      title: 'Fee Voucher Preview (${voucher.voucherNumber})',
      initialFormat: PdfPageFormat.a4,
      pdfFileName: '${voucher.voucherNumber}.pdf',
      buildPdf: (format) => PdfDocumentService.generateFeeVoucherPdf(
        voucher: voucher,
        studentName: studentName,
        rollNumber: rollNumber,
        batchName: batchName,
        academyName: academy?.name ?? 'ClassKhata Academy',
        academyPhone: academy?.phone,
        academyAddress: academy?.address,
        format: format,
      ),
    );
  }

  Future<void> _previewAllVouchers(List<FeeVoucher> vouchers) async {
    if (vouchers.isEmpty) return;
    final academy = ref.read(academyProfileProvider).valueOrNull;
    final academicData = ref.read(academicDataProvider).valueOrNull;
    final filterState = ref.read(voucherFilterProvider);
    final batch = filterState.batchId != null
        ? academicData?.batches.where((b) => b.id == filterState.batchId).firstOrNull
        : null;
    final batchName = batch?.name ?? 'School Classes';

    // Fetch student mappings
    final studentsRes = await ref.read(studentRepositoryProvider).getStudents();
    final students = studentsRes.fold(onSuccess: (s) => s, onFailure: (_) => <Student>[]);
    final studentNamesMap = {for (var s in students) s.id: s.name};
    final studentRollsMap = {for (var s in students) s.id: s.rollNumber};

    if (!mounted) return;

    PdfPrintPreviewDialog.show(
      context,
      title: 'Batch Vouchers Preview (${vouchers.length} vouchers)',
      initialFormat: PdfPageFormat.a4,
      pdfFileName: 'batch_vouchers_${filterState.monthYear ?? "all"}.pdf',
      buildPdf: (format) => PdfDocumentService.generateBatchVouchersPdf(
        vouchers: vouchers,
        studentNames: studentNamesMap,
        studentRolls: studentRollsMap,
        batchName: batchName,
        academyName: academy?.name ?? 'ClassKhata Academy',
        academyPhone: academy?.phone,
        academyAddress: academy?.address,
      ),
    );
  }

  Widget _buildVouchersTab() {
    final vouchersAsync = ref.watch(vouchersListProvider);
    final academicDataAsync = ref.watch(academicDataProvider);
    final filterState = ref.watch(voucherFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: academicDataAsync.when(
                    data: (data) => DropdownButtonFormField<int?>(
                      value: filterState.batchId,
                      decoration: const InputDecoration(labelText: 'Filter Batch'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Batches')),
                        ...data.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (val) => ref.read(voucherFilterProvider.notifier).setBatchId(val),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<VoucherStatus?>(
                    value: filterState.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: VoucherStatus.unpaid, child: Text('Unpaid')),
                      DropdownMenuItem(value: VoucherStatus.partial, child: Text('Partial')),
                      DropdownMenuItem(value: VoucherStatus.paid, child: Text('Paid')),
                      DropdownMenuItem(value: VoucherStatus.overdue, child: Text('Overdue')),
                    ],
                    onChanged: (val) => ref.read(voucherFilterProvider.notifier).setStatus(val),
                  ),
                ),
                if (vouchersAsync.valueOrNull?.isNotEmpty == true) ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: Text('Preview All (${vouchersAsync.value!.length})'),
                    onPressed: () => _previewAllVouchers(vouchersAsync.value!),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Vouchers Table
        Expanded(
          child: Card(
            child: vouchersAsync.when(
              data: (vouchers) {
                if (vouchers.isEmpty) {
                  return const Center(child: Text('No vouchers generated yet. Click "Generate Vouchers" above.'));
                }

                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Voucher #')),
                      DataColumn(label: Text('Month')),
                      DataColumn(label: Text('Due Date')),
                      DataColumn(label: Text('Base Fee')),
                      DataColumn(label: Text('Carry Over')),
                      DataColumn(label: Text('Total Due')),
                      DataColumn(label: Text('Paid')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: vouchers.map((v) {
                      return DataRow(
                        cells: [
                          DataCell(Text(v.voucherNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(v.monthYear)),
                          DataCell(Text('${v.dueDate.day}/${v.dueDate.month}/${v.dueDate.year}')),
                          DataCell(Text(v.baseAmount.format())),
                          DataCell(Text(v.carryForward.isZero ? '-' : v.carryForward.format())),
                          DataCell(Text(v.totalDue.format(), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(v.amountPaid.format())),
                          DataCell(
                            StatusBadge(
                              type: switch (v.status) {
                                VoucherStatus.paid => StatusBadgeType.paid,
                                VoucherStatus.partial => StatusBadgeType.partial,
                                VoucherStatus.overdue => StatusBadgeType.overdue,
                                _ => StatusBadgeType.pending,
                              },
                              label: v.status.name.toUpperCase(),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.accent),
                              tooltip: 'Preview & Print 3-Copy Voucher',
                              onPressed: () => _previewVoucher(v),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.overdue))),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Defaulter Aging (30 / 60 / 90+ Days)
  // ---------------------------------------------------------------------------

  Widget _buildDefaulterAgingTab() {
    final agingAsync = ref.watch(defaulterAgingProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Defaulter Aging Report (30 / 60 / 90 Days)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(defaulterAgingProvider),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: agingAsync.when(
                data: (records) {
                  if (records.isEmpty) {
                    return const Center(child: Text('No overdue records found. All accounts up to date!'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Roll No')),
                        DataColumn(label: Text('Student Name')),
                        DataColumn(label: Text('Batch')),
                        DataColumn(label: Text('Guardian Phone')),
                        DataColumn(label: Text('Total Overdue')),
                        DataColumn(label: Text('Days Overdue')),
                        DataColumn(label: Text('Aging Category')),
                      ],
                      rows: records.map((rec) {
                        return DataRow(
                          cells: [
                            DataCell(Text(rec.rollNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(rec.studentName)),
                            DataCell(Text(rec.batchName)),
                            DataCell(Text(rec.guardianPhone)),
                            DataCell(
                              Text(
                                rec.totalOverdue.format(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.overdue),
                              ),
                            ),
                            DataCell(Text('${rec.daysOverdue} days')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: rec.daysOverdue >= 60 ? AppColors.overdueBg : AppColors.pendingBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.bucket,
                                  style: TextStyle(
                                    color: rec.daysOverdue >= 60 ? AppColors.overdue : AppColors.pending,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Approvals & Adjustments (Maker-Checker)
  // ---------------------------------------------------------------------------

  Widget _buildApprovalsTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Maker-Checker Fee Adjustments & Waivers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Financial security rule: waivers, refunds, and cancellations require an independent checker approval.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const Divider(height: 24),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 48, color: AppColors.accent),
                    SizedBox(height: 12),
                    Text(
                      'No pending approval requests.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
