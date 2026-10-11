/// Record Stock Movement Dialog (Stock In / Stock Out).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/inventory_entities.dart';
import '../providers/inventory_providers.dart';

class StockMovementDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;
  final String initialMovementType; // 'in' or 'out'

  const StockMovementDialog({
    super.key,
    this.preselectedItem,
    this.initialMovementType = 'in',
  });

  @override
  ConsumerState<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<StockMovementDialog> {
  late String _movementType;
  int? _selectedItemId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _movementType = widget.initialMovementType;
    if (widget.preselectedItem != null) {
      _selectedItemId = widget.preselectedItem!.id;
      _costCtrl.text = widget.preselectedItem!.unitCost.inRupees.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _reasonCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedItemId == null) {
      setState(() => _errorMessage = 'Please select an inventory item.');
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be greater than zero.');
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Movement reason / notes are required.');
      return;
    }

    final costRupees = double.tryParse(_costCtrl.text.trim()) ?? 0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(recordStockMovementUseCaseProvider);

    final res = await useCase(
      itemId: _selectedItemId!,
      movementType: _movementType,
      quantity: qty,
      unitCost: Money.fromRupees(costRupees),
      reason: reason,
      referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryMovementsProvider);
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
    final itemsAsync = ref.watch(inventoryItemsProvider);

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
              Text(
                _movementType == 'in' ? 'Stock In (Receive Goods)' : 'Stock Out (Issue Goods)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Stock In'),
                      value: 'in',
                      groupValue: _movementType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _movementType = val ?? 'in'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Stock Out'),
                      value: 'out',
                      groupValue: _movementType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _movementType = val ?? 'out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.preselectedItem != null)
                Text(
                  'Item: ${widget.preselectedItem!.name} (${widget.preselectedItem!.quantityOnHand} ${widget.preselectedItem!.unit} available)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                )
              else
                itemsAsync.when(
                  data: (items) {
                    return DropdownButtonFormField<int>(
                      value: _selectedItemId ?? (items.isNotEmpty ? items.first.id : null),
                      decoration: const InputDecoration(labelText: 'Select Item *'),
                      items: items
                          .map((i) => DropdownMenuItem(
                                value: i.id,
                                child: Text('${i.name} (${i.quantityOnHand} ${i.unit} in stock)'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedItemId = val;
                          final match = items.firstWhere((i) => i.id == val);
                          _costCtrl.text = match.unitCost.inRupees.toString();
                        });
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _qtyCtrl,
                      label: 'Quantity *',
                      keyboardType: TextInputType.number,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _costCtrl,
                      label: 'Unit Cost (Rs.)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _reasonCtrl,
                label: _movementType == 'in'
                    ? 'Reason / Supplier / Source *'
                    : 'Issued To / Room / Purpose *',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _refCtrl,
                label: 'Invoice / PO / Reference # (Optional)',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: _movementType == 'in' ? 'Record Stock In' : 'Issue Stock Out',
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
