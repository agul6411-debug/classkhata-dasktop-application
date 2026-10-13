/// Add Expense Modal Dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/payment_modes.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/finance_providers.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  int? _selectedCategoryId;
  String _paymentMode = PaymentModes.handCash;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountRupees = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amountRupees <= 0) {
      setState(() => _errorMessage = 'Please enter a valid expense amount.');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Expense description is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(recordExpenseUseCaseProvider);

    final result = await useCase(
      categoryId: _selectedCategoryId ?? 1,
      amount: Money.fromRupees(amountRupees),
      description: _descCtrl.text.trim(),
      paymentMode: _paymentMode,
      referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(expensesListProvider);
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
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Record Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context)),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              categoriesAsync.when(
                data: (cats) {
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId ?? (cats.isNotEmpty ? cats.first.id : null),
                    decoration: const InputDecoration(labelText: 'Expense Category'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _amountCtrl,
                label: 'Amount (Rs.) *',
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descCtrl,
                label: 'Description / Purpose *',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMode,
                      decoration: const InputDecoration(labelText: 'Payment Mode'),
                      items: PaymentModes.dropdownItems,
                      onChanged: (val) => setState(() => _paymentMode = val ?? PaymentModes.handCash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _refCtrl,
                      label: 'Ref / Bill # (Optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Save Expense', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
