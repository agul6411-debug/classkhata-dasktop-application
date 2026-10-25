/// Purchase Record Modal Dialog (Multi-item purchase with Cash Book Outflow & Stock In).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/payment_modes.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../providers/inventory_providers.dart';

class PurchaseFormDialog extends ConsumerStatefulWidget {
  const PurchaseFormDialog({super.key});

  @override
  ConsumerState<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends ConsumerState<PurchaseFormDialog> {
  final _purchaseNoCtrl = TextEditingController(
      text: 'PUR-${DateTime.now().year}${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
  final _invoiceCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  int? _selectedSupplierId;
  String _paymentMode = PaymentModes.handCash;
  bool _isLoading = false;
  String? _errorMessage;

  // Multi-item lines
  final List<({int itemId, int quantity, Money unitCost})> _lines = [];

  // Current item builder controllers
  int? _lineItemId;
  final _lineQtyCtrl = TextEditingController(text: '1');
  final _lineCostCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _purchaseNoCtrl.dispose();
    _invoiceCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _lineQtyCtrl.dispose();
    _lineCostCtrl.dispose();
    super.dispose();
  }

  void _addLine() {
    if (_lineItemId == null) return;
    final qty = int.tryParse(_lineQtyCtrl.text.trim()) ?? 0;
    final costRupees = double.tryParse(_lineCostCtrl.text.trim()) ?? 0;
    if (qty <= 0) return;

    setState(() {
      _lines.add((itemId: _lineItemId!, quantity: qty, unitCost: Money.fromRupees(costRupees)));
      _lineItemId = null;
      _lineQtyCtrl.text = '1';
      _lineCostCtrl.text = '0';
    });
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  Money get _totalAmount {
    Money sum = const Money(0);
    for (final l in _lines) {
      sum += l.unitCost * l.quantity;
    }
    return sum;
  }

  Future<void> _submit() async {
    if (_selectedSupplierId == null) {
      setState(() => _errorMessage = 'Please select a supplier.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one line item.');
      return;
    }

    final paidRupees = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    final paidMoney = Money.fromRupees(paidRupees);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(recordPurchaseUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
      purchaseNumber: _purchaseNoCtrl.text.trim(),
      supplierId: _selectedSupplierId!,
      items: _lines,
      paidAmount: paidMoney,
      paymentMode: _paymentMode,
      invoiceNumber: _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(purchasesProvider);
        ref.invalidate(suppliersProvider);
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryMovementsProvider);
        ref.invalidate(stockValuationProvider);
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
    final itemsAsync = ref.watch(inventoryItemsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Record Inventory Purchase',
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

                // Supplier Selector
                suppliersAsync.when(
                  data: (suppliers) => DropdownButtonFormField<int>(
                    initialValue: _selectedSupplierId,
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
                    onChanged: (id) => setState(() => _selectedSupplierId = id),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Failed to load suppliers: $err'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _purchaseNoCtrl,
                        label: 'Purchase Ref # *',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        controller: _invoiceCtrl,
                        label: 'Supplier Invoice #',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Multi-Item Builder Section
                const Text(
                  'Purchase Line Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.heading),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: itemsAsync.when(
                        data: (items) => DropdownButtonFormField<int>(
                          initialValue: _lineItemId,
                          decoration: const InputDecoration(
                            labelText: 'Add Item',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: items
                              .map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.unit})')))
                              .toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final it = items.firstWhere((x) => x.id == id);
                            setState(() {
                              _lineItemId = id;
                              _lineCostCtrl.text = it.unitCost.inRupees.toString();
                            });
                          },
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _lineQtyCtrl,
                        label: 'Qty',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _lineCostCtrl,
                        label: 'Cost (PKR)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _addLine,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lines List
                if (_lines.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final l = _lines[idx];
                        final lineTotal = l.unitCost * l.quantity;
                        return ListTile(
                          dense: true,
                          title: Text('Item #${l.itemId}'),
                          subtitle: Text('${l.quantity} units @ ${l.unitCost.format()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(lineTotal.format(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _removeLine(idx),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Summary & Payment Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Purchase Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        _totalAmount.format(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _paidCtrl,
                        label: 'Amount Paid Now (PKR)',
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
                        items: [
                          ...PaymentModes.dropdownItems,
                          const DropdownMenuItem(
                            value: 'credit',
                            child: Row(
                              children: [
                                Icon(Icons.credit_card_off_outlined, size: 16, color: Colors.purple),
                                SizedBox(width: 8),
                                Text('On Credit (Pay Later)'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _paymentMode = val ?? PaymentModes.handCash),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _notesCtrl,
                  label: 'Notes / Remarks',
                  hint: 'Optional purchase remarks',
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
                      label: 'Record Purchase',
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
      ),
    );
  }
}
