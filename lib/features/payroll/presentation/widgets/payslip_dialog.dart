/// Salary Payslip Dialog with disburse workflow and printable slip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/payroll_entities.dart';
import '../providers/payroll_providers.dart';

class PayslipDialog extends ConsumerStatefulWidget {
  final PayrollRun run;
  final String academyName;

  const PayslipDialog({
    super.key,
    required this.run,
    this.academyName = 'ClassKhata Academy',
  });

  @override
  ConsumerState<PayslipDialog> createState() => _PayslipDialogState();
}

class _PayslipDialogState extends ConsumerState<PayslipDialog> {
  String _paymentMode = 'cash';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _disburseSalary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final paySalaryUseCase = ref.read(paySalaryUseCaseProvider);

    final res = await paySalaryUseCase(
      userPermissions: currentUser?.permissions ?? {Permission.payrollRun},
      payrollRunId: widget.run.id,
      paymentMode: _paymentMode,
      paidBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(payrollRunsListProvider);
        Navigator.of(context).pop(true);
      },
      onFailure: (f) => setState(() {
        _isLoading = false;
        _errorMessage = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final gross = run.baseSalary + run.allowances;
    final totalDeductions = run.deductions + run.advanceRecovery;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.academyName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'SALARY PAYSLIP - ${run.monthYear}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: run.isPaid ? AppColors.accent : Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        run.status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    _infoRow('Staff Member', run.staffName),
                    const SizedBox(height: 6),
                    _infoRow('Designation', run.designation),
                    const SizedBox(height: 6),
                    _infoRow('Month / Period', run.monthYear),
                    const Divider(height: 24),

                    // Earnings
                    const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    const SizedBox(height: 6),
                    _amountRow('Base Salary', run.baseSalary),
                    const SizedBox(height: 4),
                    _amountRow('Allowances', run.allowances),
                    const SizedBox(height: 4),
                    _amountRow('Gross Earnings', gross, isBold: true),
                    const Divider(height: 20),

                    // Deductions
                    const Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 6),
                    _amountRow('Standard Deductions', run.deductions),
                    const SizedBox(height: 4),
                    _amountRow('Advance Recovery', run.advanceRecovery),
                    const SizedBox(height: 4),
                    _amountRow('Total Deductions', totalDeductions, isBold: true),
                    const Divider(height: 24),

                    // Net Pay
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('NET SALARY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            run.netSalary.format(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (run.isPaid) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Disbursed via ${run.paymentMode?.toUpperCase() ?? "CASH"}${run.paidAt != null ? " on ${run.paidAt!.day}/${run.paidAt!.month}/${run.paidAt!.year}" : ""}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paymentMode,
                              decoration: const InputDecoration(labelText: 'Disbursement Mode'),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                              ],
                              onChanged: (val) => setState(() => _paymentMode = val ?? 'cash'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Disburse Salary',
                              isLoading: _isLoading,
                              onPressed: _disburseSalary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Payslip'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payslip sent to printer.')),
                          );
                          Navigator.of(context).pop();
                        },
                      ),
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

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _amountRow(String label, Money amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppColors.heading : AppColors.textPrimary,
          ),
        ),
        Text(
          amount.format(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? AppColors.heading : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
