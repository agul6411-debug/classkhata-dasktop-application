/// Issue Staff Advance Modal Dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/payroll_providers.dart';

class AdvanceFormDialog extends ConsumerStatefulWidget {
  const AdvanceFormDialog({super.key});

  @override
  ConsumerState<AdvanceFormDialog> createState() => _AdvanceFormDialogState();
}

class _AdvanceFormDialogState extends ConsumerState<AdvanceFormDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  int? _selectedStaffId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStaffId == null) {
      setState(() => _errorMessage = 'Please select a staff member.');
      return;
    }

    final amountRupees = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amountRupees <= 0) {
      setState(() => _errorMessage = 'Advance amount must be greater than zero.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final repo = ref.read(payrollRepositoryProvider);

    final res = await repo.issueAdvance(
      staffId: _selectedStaffId!,
      amount: Money.fromRupees(amountRupees),
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(staffAdvancesListProvider);
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
    final staffAsync = ref.watch(staffListProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Issue Salary Advance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              staffAsync.when(
                data: (staffList) {
                  return DropdownButtonFormField<int>(
                    value: _selectedStaffId ?? (staffList.isNotEmpty ? staffList.first.id : null),
                    decoration: const InputDecoration(labelText: 'Staff Member *'),
                    items: staffList
                        .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.designation})')))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStaffId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _amountCtrl,
                label: 'Advance Amount (Rs.) *',
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _reasonCtrl,
                label: 'Reason / Purpose (Optional)',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Issue Advance', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
