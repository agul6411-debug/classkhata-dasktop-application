/// Main Payroll Page for staff, salary runs, advances, and payslips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/payroll_entities.dart';
import '../providers/payroll_providers.dart';
import '../widgets/advance_form_dialog.dart';
import '../widgets/payslip_dialog.dart';
import '../widgets/staff_form_dialog.dart';

class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({super.key});

  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isGeneratingRuns = false;

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
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StaffFormDialog(),
                      ),
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

    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderCol(context)),
              ),
              child: Row(
                children: [
                  const Text('Month: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: selectedMonth,
                    underline: const SizedBox.shrink(),
                    items: List.generate(6, (i) {
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
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: runsAsync.when(
            data: (runs) {
              if (runs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No payroll generated for $selectedMonth yet.', style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _runMonthlyPayroll, child: const Text('Generate Payroll for this Month')),
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
                      DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Base Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Allowances', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Adv. Recovered', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Net Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: runs.map((run) {
                      return DataRow(
                        cells: [
                          DataCell(Text(run.staffName, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(run.designation)),
                          DataCell(Text(run.baseSalary.format())),
                          DataCell(Text(run.allowances.format())),
                          DataCell(Text(run.deductions.format())),
                          DataCell(Text(run.advanceRecovery.format())),
                          DataCell(Text(run.netSalary.format(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent))),
                          DataCell(StatusBadge(
                            label: run.status.toUpperCase(),
                            type: run.isPaid ? StatusBadgeType.paid : StatusBadgeType.pending,
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading payroll: $err', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ],
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
                  onPressed: () => showDialog<bool>(context: context, builder: (_) => const StaffFormDialog()),
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
