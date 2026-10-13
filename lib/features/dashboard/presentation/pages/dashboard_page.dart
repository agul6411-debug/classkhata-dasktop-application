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
import '../../../students/presentation/widgets/student_form_dialog.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionNotifierProvider);
    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final kpisAsync = ref.watch(dashboardKpisProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Academy operational and financial summary.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                // Month selector
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.calendar_month, color: AppColors.accent, size: 20),
                        items: _generateMonthOptions().map((m) {
                          return DropdownMenuItem(value: m.value, child: Text(m.label));
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
                        icon: const Icon(Icons.refresh, color: AppColors.accent),
                        onPressed: () {
                          ref.invalidate(dashboardKpisProvider);
                          ref.invalidate(academicDataProvider);
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
                    const Text('Quick Actions:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const AddExpenseDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_clock, size: 16),
                      label: const Text('Day Closing'),
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

            // Financial KPIs Cards Grid
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
                          color: AppColors.heading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Collected (${kpis.collectionPercentage.toStringAsFixed(0)}%)',
                          value: kpis.collectedTotal.format(),
                          icon: Icons.check_circle_outline,
                          color: AppColors.paid,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Pending',
                          value: kpis.pendingTotal.format(),
                          icon: Icons.hourglass_top,
                          color: AppColors.pending,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kpiCard(
                          title: 'Overdue',
                          value: kpis.overdueTotal.format(),
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.overdue,
                        ),
                      ),
                    ],
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
                                const Text('School Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Divider(height: 20),
                                _directoryRow(Icons.school, 'Active Students', kpis.studentsCount.toString()),
                                const SizedBox(height: 12),
                                _directoryRow(Icons.auto_stories, 'School Classes', kpis.coursesCount.toString()),
                                const SizedBox(height: 12),
                                _directoryRow(Icons.groups, 'Class Sections', kpis.batchesCount.toString()),
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
                                    const Text('Fee Collection Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Month: ${kpis.monthYear}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  ],
                                ),
                                const Divider(height: 20),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _statusPill('Paid', kpis.paidCount, AppColors.paid, AppColors.paidBg),
                                    _statusPill('Partial', kpis.partialCount, AppColors.pending, AppColors.pendingBg),
                                    _statusPill('Unpaid', kpis.unpaidCount, AppColors.textMuted, AppColors.inputFill),
                                    _statusPill('Overdue', kpis.overdueCount, AppColors.overdue, AppColors.overdueBg),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                LinearProgressIndicator(
                                  value: kpis.expectedTotal.isZero
                                      ? 0
                                      : (kpis.collectedTotal.paisa / kpis.expectedTotal.paisa).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                  color: AppColors.paid,
                                  backgroundColor: AppColors.inputFill,
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
                      color: AppColors.pendingBg,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active, color: AppColors.pending, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Actionable Alerts (${kpis.alerts.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.heading),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...kpis.alerts.take(3).map((a) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('• ${a.title}: ${a.message}', style: const TextStyle(fontSize: 13)),
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
                Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
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

  Widget _directoryRow(IconData icon, String label, String count) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.heading)),
      ],
    );
  }

  Widget _statusPill(String label, int count, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text(label, style: TextStyle(fontSize: 11, color: textColor)),
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
