/// Main Payroll Page for staff, salary runs, advances, and payslips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/payroll_entities.dart';
import '../../domain/entities/staff_profile.dart';
import '../../domain/services/staff_profile_service.dart';
import '../providers/payroll_providers.dart';
import '../widgets/advance_form_dialog.dart';
import '../widgets/payslip_dialog.dart';
import '../widgets/staff_form_dialog.dart';
import '../widgets/staff_terms_editor_dialog.dart';

class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({super.key});

  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isGeneratingRuns = false;
  String _payrollFilter = 'all'; // 'all', 'paid', 'pending'

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

  Future<void> _openAddStaffDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => const StaffFormDialog(),
    );
    if (result is Map && result['print'] == true) {
      final staff = result['staff'] as StaffMember;
      final profile = result['profile'] as StaffProfile;
      if (mounted) {
        _printStaffDossier(staff, profile);
      }
    }
  }

  Future<void> _printStaffDossier(StaffMember staff, [StaffProfile? profile]) async {
    final db = ref.read(appDatabaseProvider);
    final loadedProfile = profile ?? await StaffProfileService.getProfile(db: db, staffId: staff.id);
    final academy = ref.read(academyProfileProvider).valueOrNull;
    final schoolTerms = await StaffProfileService.getSchoolTerms(db);

    if (!mounted) return;

    PdfPrintPreviewDialog.show(
      context,
      title: 'Staff Dossier & Employment Agreement (${staff.staffCode})',
      pdfFileName: 'Staff_${staff.staffCode}_Dossier.pdf',
      initialFormat: PdfPageFormat.a4,
      pageFormats: {'A4': PdfPageFormat.a4},
      buildPdf: (format) => PdfDocumentService.generateStaffJoiningDossierPdf(
        staff: staff,
        profile: loadedProfile,
        academyName: academy?.name ?? 'ClassKhata Academy',
        academyTagline: academy?.tagline,
        academyPhone: academy?.phone,
        academyAddress: academy?.address,
        logoPath: academy?.logoPath,
        schoolTerms: schoolTerms,
        format: format,
      ),
    );
  }

  Future<void> _runMonthlyPayroll() async {
    setState(() => _isGeneratingRuns = true);
    final month = ref.read(selectedPayrollMonthProvider);
    final currentUser = ref.read(authSessionNotifierProvider);
    final runUseCase = ref.read(runMonthlyPayrollUseCaseProvider);

    final res = await runUseCase(
      userPermissions: currentUser?.permissions ?? {Permission.payrollRun},
      monthYear: month,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;
    setState(() => _isGeneratingRuns = false);

    res.fold(
      onSuccess: (count) {
        ref.invalidate(payrollRunsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'Generated $count payroll records for $month.'
                : 'Payroll records already up to date for $month.'),
          ),
        );
      },
      onFailure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${f.message}'), backgroundColor: Colors.red),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payroll & Staff Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: headingColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff profiles, salary structures, advances, monthly payroll runs, and payslips.',
                      style: TextStyle(color: textMutedColor, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.gavel, size: 16),
                      label: const Text('Staff Terms & Rules'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                      ),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StaffTermsEditorDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.money_off, size: 16),
                      label: const Text('Issue Advance'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                      ),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const AdvanceFormDialog(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Add Staff Member',
                      icon: Icons.person_add,
                      onPressed: _openAddStaffDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: isDark ? AppColors.accentLight : AppColors.accent,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                indicatorColor: isDark ? AppColors.accentLight : AppColors.accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Monthly Payroll Register'),
                  Tab(text: 'Staff Directory'),
                  Tab(text: 'Salary Advances'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPayrollRegisterTab(),
                  _buildStaffDirectoryTab(),
                  _buildAdvancesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Monthly Payroll Register
  // ---------------------------------------------------------------------------
  Widget _buildPayrollRegisterTab() {
    final runsAsync = ref.watch(payrollRunsListProvider);
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;

    return runsAsync.when(
      data: (runs) {
        // Compute payroll metrics
        int totalPayrollPaisa = 0;
        int totalGrossPaisa = 0;
        int totalPaidPaisa = 0;
        int totalPendingPaisa = 0;
        int totalAdvanceRecoveryPaisa = 0;
        int paidCount = 0;
        int pendingCount = 0;

        for (final r in runs) {
          totalGrossPaisa += (r.baseSalary + r.allowances).paisa;
          totalPayrollPaisa += r.netSalary.paisa;
          totalAdvanceRecoveryPaisa += r.advanceRecovery.paisa;
          if (r.isPaid) {
            totalPaidPaisa += r.netSalary.paisa;
            paidCount++;
          } else {
            totalPendingPaisa += r.netSalary.paisa;
            pendingCount++;
          }
        }

        final displayedRuns = runs.where((r) {
          if (_payrollFilter == 'paid') return r.isPaid;
          if (_payrollFilter == 'pending') return !r.isPaid;
          return true;
        }).toList();

        Widget buildKpiCard({
          required String title,
          required String value,
          required String subtitle,
          required IconData icon,
          required Color color,
          VoidCallback? onTap,
          bool isSelected = false,
        }) {
          return Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderCol(context),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textMutedColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: headingColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Top Analytics KPI Summary Cards
            Row(
              children: [
                buildKpiCard(
                  title: 'Total Monthly Payroll',
                  value: Money(totalPayrollPaisa).format(),
                  subtitle: 'Gross: ${Money(totalGrossPaisa).format()}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.accent,
                  onTap: () => setState(() => _payrollFilter = 'all'),
                  isSelected: _payrollFilter == 'all',
                ),
                const SizedBox(width: 12),
                buildKpiCard(
                  title: 'Paid Salaries',
                  value: Money(totalPaidPaisa).format(),
                  subtitle: '$paidCount Staff Disbursed',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  onTap: () => setState(() => _payrollFilter = 'paid'),
                  isSelected: _payrollFilter == 'paid',
                ),
                const SizedBox(width: 12),
                buildKpiCard(
                  title: 'Pending Disbursement',
                  value: Money(totalPendingPaisa).format(),
                  subtitle: '$pendingCount Staff Pending',
                  icon: Icons.pending_actions_outlined,
                  color: Colors.orange.shade800,
                  onTap: () => setState(() => _payrollFilter = 'pending'),
                  isSelected: _payrollFilter == 'pending',
                ),
                const SizedBox(width: 12),
                buildKpiCard(
                  title: 'Advance Deductions',
                  value: Money(totalAdvanceRecoveryPaisa).format(),
                  subtitle: 'Total Recovered from Advance',
                  icon: Icons.price_check_outlined,
                  color: Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Controls & Filter Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderCol(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          const Text('Payroll Month: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          DropdownButton<String>(
                            value: selectedMonth,
                            underline: const SizedBox.shrink(),
                            items: List.generate(12, (i) {
                              final dt = DateTime.now().subtract(Duration(days: 30 * i));
                              final val = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
                              return DropdownMenuItem(value: val, child: Text(val));
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(selectedPayrollMonthProvider.notifier).state = val;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isGeneratingRuns
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.calculate, size: 16),
                      label: const Text('Run Monthly Payroll'),
                      onPressed: _isGeneratingRuns ? null : _runMonthlyPayroll,
                    ),
                  ],
                ),
                // Status Filter Segment
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderCol(context)),
                  ),
                  child: Row(
                    children: [
                      _buildFilterChip('All (${runs.length})', 'all'),
                      _buildFilterChip('Paid ($paidCount)', 'paid'),
                      _buildFilterChip('Pending ($pendingCount)', 'pending'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Table Body
            Expanded(
              child: runs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('No payroll generated for $selectedMonth yet.', style: const TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Generate Payroll for this Month'),
                            onPressed: _runMonthlyPayroll,
                          ),
                        ],
                      ),
                    )
                  : displayedRuns.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.filter_list_off, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text('No records matching the "$_payrollFilter" filter.', style: const TextStyle(color: AppColors.textMuted)),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () => setState(() => _payrollFilter = 'all'),
                                child: const Text('Show All Records'),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderCol(context)),
                          ),
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Base Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Allowances', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Adv. Deducted', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Net Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: displayedRuns.map((run) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(run.staffName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(run.designation)),
                                      DataCell(Text(run.baseSalary.format())),
                                      DataCell(Text(run.allowances.format())),
                                      DataCell(Text(run.deductions.format())),
                                      // Advance Recovery Highlight Badge
                                      DataCell(
                                        run.advanceRecovery.paisa > 0
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurple.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.deepPurple.shade200),
                                                ),
                                                child: Text(
                                                  '- ${run.advanceRecovery.format()}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 12),
                                                ),
                                              )
                                            : const Text('-', style: TextStyle(color: AppColors.textMuted)),
                                      ),
                                      DataCell(Text(run.netSalary.format(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent))),
                                      DataCell(StatusBadge(
                                        label: run.status.toUpperCase(),
                                        type: run.isPaid ? StatusBadgeType.paid : StatusBadgeType.pending,
                                      )),
                                      // Payment Date Column (User Requested: kon c date ko salary mili)
                                      DataCell(
                                        run.isPaid && run.paidAt != null
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.event_available, size: 14, color: Colors.green),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${run.paidAt!.day.toString().padLeft(2, '0')}/${run.paidAt!.month.toString().padLeft(2, '0')}/${run.paidAt!.year}',
                                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '(${run.paymentMode?.toUpperCase() ?? "CASH"})',
                                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'Pending / Unpaid',
                                                style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                                              ),
                                      ),
                                      // Actions Column (Pay Salary button + Payslip)
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!run.isPaid) ...[
                                              FilledButton.icon(
                                                icon: const Icon(Icons.payments_outlined, size: 13),
                                                label: const Text('Pay Salary', style: TextStyle(fontSize: 11)),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  minimumSize: const Size(0, 30),
                                                ),
                                                onPressed: () => showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => PayslipDialog(run: run),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            IconButton(
                                              icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.accent),
                                              tooltip: 'View / Print Payslip',
                                              onPressed: () => showDialog<bool>(
                                                context: context,
                                                builder: (_) => PayslipDialog(run: run),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading payroll: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _payrollFilter == value;
    return InkWell(
      onTap: () => setState(() => _payrollFilter = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Staff Directory
  // ---------------------------------------------------------------------------
  Widget _buildStaffDirectoryTab() {
    final staffAsync = ref.watch(staffListProvider);

    return staffAsync.when(
      data: (staffList) {
        if (staffList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('No staff members registered yet.', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openAddStaffDialog,
                  child: const Text('Add First Staff Member'),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderCol(context)),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Staff Code', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('CNIC', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Joined Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: staffList.map((s) {
                return DataRow(
                  cells: [
                    DataCell(Text(s.staffCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(s.phone)),
                    DataCell(Text(s.designation)),
                    DataCell(Text(s.cnic ?? '-')),
                    DataCell(Text('${s.joiningDate.day}/${s.joiningDate.month}/${s.joiningDate.year}')),
                    DataCell(StatusBadge(
                      label: s.status.name.toUpperCase(),
                      type: s.status == StaffStatus.active ? StatusBadgeType.active : StatusBadgeType.inactive,
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print, size: 18, color: AppColors.accent),
                            tooltip: 'Print 2-Page Registration Dossier & Agreement',
                            onPressed: () => _printStaffDossier(s),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading staff: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Salary Advances
  // ---------------------------------------------------------------------------
  Widget _buildAdvancesTab() {
    final advAsync = ref.watch(staffAdvancesListProvider);

    return advAsync.when(
      data: (advances) {
        if (advances.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('No staff advances issued yet.', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => showDialog<bool>(context: context, builder: (_) => const AdvanceFormDialog()),
                  child: const Text('Issue Salary Advance'),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderCol(context)),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Advance ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Staff ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Issued Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Recovered', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Issue Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: advances.map((adv) {
                return DataRow(
                  cells: [
                    DataCell(Text('#ADV-${adv.id.toString().padLeft(4, '0')}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text('Staff #${adv.staffId}')),
                    DataCell(Text(adv.amount.format(), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(adv.recovered.format(), style: const TextStyle(color: Colors.green))),
                    DataCell(Text(adv.remaining.format(), style: TextStyle(fontWeight: FontWeight.bold, color: adv.remaining.isZero ? Colors.green : Colors.red))),
                    DataCell(Text('${adv.issueDate.day}/${adv.issueDate.month}/${adv.issueDate.year}')),
                    DataCell(StatusBadge(
                      label: adv.isFullyRecovered ? 'RECOVERED' : 'OUTSTANDING',
                      type: adv.isFullyRecovered ? StatusBadgeType.paid : StatusBadgeType.pending,
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading advances: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}
