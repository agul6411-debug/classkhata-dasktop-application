/// Supplier Management Modal Dialogs: Add Supplier & Record Supplier Payment.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({super.key});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _openBalCtrl = TextEditingController(text: '0');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _openBalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Supplier name is required.');
      return;
    }

    final openBalRupees = double.tryParse(_openBalCtrl.text.trim()) ?? 0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final repo = ref.read(inventoryRepositoryProvider);

    final res = await repo.createSupplier(
      name: name,
      contactPerson: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      openingBalance: Money.fromRupees(openBalRupees),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(suppliersProvider);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Supplier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.headingCol(context)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],

              AppTextField(
                controller: _nameCtrl,
                label: 'Supplier / Company Name *',
                hint: 'e.g. Oxford Book Depot, Allied Stationers',
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _contactCtrl,
                      label: 'Contact Person',
                      hint: 'Representative name',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _emailCtrl,
                      label: 'Email (Optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _openBalCtrl,
                      label: 'Opening Payable (PKR)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _addressCtrl,
                label: 'Shop / Warehouse Address',
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: 'Save Supplier',
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupplierPaymentDialog extends ConsumerStatefulWidget {

  const SupplierPaymentDialog({super.key, this.preselectedSupplierId});
  final int? preselectedSupplierId;

  @override
  ConsumerState<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends ConsumerState<SupplierPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _supplierId;
  String _paymentMode = 'cash';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _supplierId = widget.preselectedSupplierId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_supplierId == null) {
      setState(() => _errorMessage = 'Please select a supplier.');
      return;
    }

    final amountRupees = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amountRupees <= 0) {
      setState(() => _errorMessage = 'Payment amount must be greater than zero.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(recordSupplierPaymentUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
      supplierId: _supplierId!,
      amount: Money.fromRupees(amountRupees),
      paymentMode: _paymentMode,
      referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(suppliersProvider);
        ref.invalidate(supplierLedgerProvider(_supplierId!));
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
    final suppliersAsync = ref.watch(suppliersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Supplier Payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.headingCol(context)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],

              suppliersAsync.when(
                data: (suppliers) => DropdownButtonFormField<int>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(
                    labelText: 'Select Supplier *',
                    border: OutlineInputBorder(),
                  ),
                  items: suppliers
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (Balance: ${s.currentBalance.format()})'),
                          ))
                      .toList(),
                  onChanged: (id) => setState(() => _supplierId = id),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error loading suppliers: $err'),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _amountCtrl,
                      label: 'Payment Amount (PKR) *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                      ],
                      onChanged: (val) => setState(() => _paymentMode = val ?? 'cash'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _refCtrl,
                label: 'Cheque / Transaction Ref #',
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _notesCtrl,
                label: 'Payment Remarks / Notes',
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: 'Record Payment',
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
