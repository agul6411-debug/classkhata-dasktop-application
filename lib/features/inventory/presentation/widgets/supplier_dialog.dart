/// Supplier Management Modal Dialogs: Add Supplier & Record Supplier Payment.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/inventory_entities.dart';
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

              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
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
        ref.invalidate(dashboardProfitLossProvider);
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

              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
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

class SupplierLedgerDialog extends ConsumerWidget {
  const SupplierLedgerDialog({super.key, required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(supplierLedgerProvider(supplier.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${supplier.name} - Statement & Khata',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingCol(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contact: ${supplier.contactPerson ?? "N/A"} | Phone: ${supplier.phone ?? "N/A"}${supplier.address != null ? " | ${supplier.address}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: supplier.currentBalance.paisa > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: supplier.currentBalance.paisa > 0 ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding Payable Balance:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: supplier.currentBalance.paisa > 0 ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                    Text(
                      supplier.currentBalance.format(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: supplier.currentBalance.paisa > 0 ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ledgerAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text(
                          'No transaction entries found for this supplier.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final entry = entries[idx];
                        final isPurchase = entry.transactionType == 'purchase';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isPurchase ? Icons.shopping_bag_outlined : Icons.payments_outlined,
                            color: isPurchase ? Colors.orange : Colors.green,
                          ),
                          title: Text(
                            '${isPurchase ? "Purchase Bill" : "Payment"} (${entry.referenceNumber ?? "N/A"})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy').format(entry.transactionDate)} | ${entry.notes ?? ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          trailing: Text(
                            entry.amount.format(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPurchase ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading ledger: $e')),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
