/// Executive Dashboard Page featuring KPIs, month picker, breakdown, alerts, and quick actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fees/presentation/widgets/fee_collection_wizard.dart';
import '../../../finance/presentation/widgets/add_expense_dialog.dart';
import '../../../finance/presentation/widgets/day_closing_dialog.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';
import '../../../students/presentation/widgets/student_form_dialog.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionNotifierProvider);
    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final pnlAsync = ref.watch(dashboardProfitLossProvider);
    final staffAsync = ref.watch(staffListProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Welcome & Month Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.name ?? "Administrator"}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: headingColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Academy operational and financial summary.',
                      style: TextStyle(color: textMutedColor, fontSize: 13),
                    ),
                  ],
                ),
                // Month selector
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        underline: const SizedBox.shrink(),
                        dropdownColor: surfaceColor,
                        icon: const Icon(Icons.calendar_month, color: AppColors.accentLight, size: 20),
                        items: _generateMonthOptions().map((m) {
                          return DropdownMenuItem(
                            value: m.value,
                            child: Text(m.label, style: TextStyle(color: textPrimaryColor, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(selectedDashboardMonthProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Refresh Dashboard',
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.accentLight),
                        onPressed: () {
                          ref.invalidate(dashboardKpisProvider);
                          ref.invalidate(dashboardProfitLossProvider);
                          ref.invalidate(academicDataProvider);
                          ref.invalidate(staffListProvider);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Quick Actions:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textMutedColor),
                    ),
                    const SizedBox(width: 16),
                    PrimaryButton(
                      label: 'Collect Fee',
                      icon: Icons.payments,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const FeeCollectionWizard(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Student'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                      ),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => const StudentFormDialog(),
                        );
                        ref.invalidate(dashboardKpisProvider);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.money_off, size: 16),
                      label: const Text('Record Expense'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const AddExpenseDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_clock, size: 16),
                      label: const Text('Day Closing'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const DayClosingDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // KPI Cards Row
            kpisAsync.when(
              data: (kpis) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          title: 'Expected Total',
                          value: kpis.expectedTotal.format(),
                          icon: Icons.account_balance_wallet_outlined,
                          color: headingColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Collected (${kpis.collectionPercentage.toStringAsFixed(0)}%)',
                          value: kpis.collectedTotal.format(),
                          icon: Icons.check_circle_outline,
                          color: isDark ? const Color(0xFF4ADE80) : AppColors.paid,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Pending',
                          value: kpis.pendingTotal.format(),
                          icon: Icons.hourglass_top,
                          color: isDark ? const Color(0xFFFBBF24) : AppColors.pending,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Overdue',
                          value: kpis.overdueTotal.format(),
                          icon: Icons.warning_amber_rounded,
                          color: isDark ? const Color(0xFFF87171) : AppColors.overdue,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Overall Financial Operations Summary (Income vs Expenses vs Surplus)
                  pnlAsync.when(
                    data: (pnl) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance, color: AppColors.accentLight, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'School Financial Operations ($selectedMonth)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: headingColor),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: pnl.isProfitable
                                        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.7) : AppColors.paidBg)
                                        : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.7) : AppColors.overdueBg),
                                    borderRadius: BorderRadius.circular(6),
                                    border: isDark
                                        ? Border.all(color: pnl.isProfitable ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFDC2626).withValues(alpha: 0.5))
                                        : null,
                                  ),
                                  child: Text(
                                    pnl.isProfitable
                                        ? 'Surplus (+${pnl.marginPercentage.toStringAsFixed(1)}%)'
                                        : 'Deficit (${pnl.marginPercentage.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: pnl.isProfitable
                                          ? (isDark ? const Color(0xFF4ADE80) : AppColors.paid)
                                          : (isDark ? const Color(0xFFF87171) : AppColors.overdue),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _financialStatTile(
                                    title: 'Fees & Inflow',
                                    amount: pnl.totalIncome.format(),
                                    subtitle: 'Total fee collections & receipts',
                                    color: isDark ? const Color(0xFF4ADE80) : AppColors.paid,
                                    icon: Icons.trending_up,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _financialStatTile(
                                    title: 'Expenses & Payroll',
                                    amount: pnl.totalExpenses.format(),
                                    subtitle: 'Salaries, stock & operating expenses',
                                    color: isDark ? const Color(0xFFF87171) : AppColors.overdue,
                                    icon: Icons.trending_down,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _financialStatTile(
                                    title: 'Net Operating Balance',
                                    amount: pnl.netProfit.format(),
                                    subtitle: pnl.isProfitable ? 'Operational surplus' : 'Operational deficit',
                                    color: pnl.isProfitable
                                        ? (isDark ? AppColors.accentLight : AppColors.accent)
                                        : (isDark ? const Color(0xFFF87171) : AppColors.overdue),
                                    icon: Icons.savings_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),

                  // Counts & Voucher Breakdown Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Counts
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('School Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: headingColor)),
                                const Divider(height: 20),
                                _directoryRow(Icons.school, 'Active Students', kpis.studentsCount.toString(), isDark),
                                const SizedBox(height: 12),
                                _directoryRow(Icons.auto_stories, 'School Classes', kpis.coursesCount.toString(), isDark),
                                const SizedBox(height: 12),
                                _directoryRow(Icons.groups, 'Class Sections', kpis.batchesCount.toString(), isDark),
                                const SizedBox(height: 12),
                                _directoryRow(Icons.badge_outlined, 'Staff & Teachers', (staffAsync.valueOrNull?.length ?? 0).toString(), isDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Monthly Voucher Breakdown
                      Expanded(
                        flex: 3,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Fee Collection Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: headingColor)),
                                    Text('Month: ${kpis.monthYear}', style: TextStyle(fontSize: 12, color: textMutedColor)),
                                  ],
                                ),
                                const Divider(height: 20),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _statusPill(
                                      'Paid',
                                      kpis.paidCount,
                                      isDark ? const Color(0xFF4ADE80) : AppColors.paid,
                                      AppColors.paidBg,
                                      isDark,
                                    ),
                                    _statusPill(
                                      'Partial',
                                      kpis.partialCount,
                                      isDark ? const Color(0xFFFBBF24) : AppColors.pending,
                                      AppColors.pendingBg,
                                      isDark,
                                    ),
                                    _statusPill(
                                      'Unpaid',
                                      kpis.unpaidCount,
                                      isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                                      isDark ? AppColors.darkCardSub : AppColors.inputFill,
                                      isDark,
                                    ),
                                    _statusPill(
                                      'Overdue',
                                      kpis.overdueCount,
                                      isDark ? const Color(0xFFF87171) : AppColors.overdue,
                                      AppColors.overdueBg,
                                      isDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                LinearProgressIndicator(
                                  value: kpis.expectedTotal.isZero
                                      ? 0
                                      : (kpis.collectedTotal.paisa / kpis.expectedTotal.paisa).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                  color: isDark ? const Color(0xFF4ADE80) : AppColors.paid,
                                  backgroundColor: isDark ? AppColors.darkCardSub : AppColors.inputFill,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Due Date Alerts
                  if (kpis.alerts.isNotEmpty) ...[
                    Card(
                      color: isDark ? const Color(0xFF451A03) : AppColors.pendingBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? const Color(0xFFB45309) : AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notifications_active, color: isDark ? const Color(0xFFFBBF24) : AppColors.pending, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Actionable Alerts (${kpis.alerts.length})',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFDE68A) : AppColors.heading),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...kpis.alerts.take(3).map((a) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '• ${a.title}: ${a.message}',
                                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFFDE68A) : AppColors.textPrimary),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (err, _) => Center(child: Text('Error loading dashboard: $err', style: const TextStyle(color: AppColors.overdue))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted, fontSize: 13)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directoryRow(IconData icon, String label, String count, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentLight),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
        Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkTextPrimary : AppColors.heading)),
      ],
    );
  }

  Widget _statusPill(String label, int count, Color textColor, Color bgColor, bool isDark) {
    final pillBg = isDark ? textColor.withValues(alpha: 0.16) : bgColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(6),
        border: isDark ? Border.all(color: textColor.withValues(alpha: 0.35)) : null,
      ),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text(label, style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }

  Widget _financialStatTile({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    final bgColor = isDark ? AppColors.darkCardSub : AppColors.inputFill;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w600)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: mutedColor)),
        ],
      ),
    );
  }

  List<({String label, String value})> _generateMonthOptions() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      final monthStr = d.month.toString().padLeft(2, '0');
      const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return (
        label: '${monthNames[d.month]} ${d.year}',
        value: '${d.year}-$monthStr',
      );
    });
  }
}
