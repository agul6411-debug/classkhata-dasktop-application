/// Physical Stock-Take & Shrinkage Reconciliation Dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/inventory_entities.dart';
import '../providers/inventory_providers.dart';

class StockReconcileDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;

  const StockReconcileDialog({
    super.key,
    this.preselectedItem,
  });

  @override
  ConsumerState<StockReconcileDialog> createState() => _StockReconcileDialogState();
}

class _StockReconcileDialogState extends ConsumerState<StockReconcileDialog> {
  int? _selectedItemId;
  int _recordedQty = 0;
  final _actualQtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItem != null) {
      _selectedItemId = widget.preselectedItem!.id;
      _recordedQty = widget.preselectedItem!.quantityOnHand;
      _actualQtyCtrl.text = _recordedQty.toString();
    }
  }

  @override
  void dispose() {
    _actualQtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedItemId == null) {
      setState(() => _errorMessage = 'Please select an item.');
      return;
    }

    final actualQty = int.tryParse(_actualQtyCtrl.text.trim());
    if (actualQty == null || actualQty < 0) {
      setState(() => _errorMessage = 'Please enter a valid actual physical count (>= 0).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(stockReconciliationUseCaseProvider);

    final res = await useCase(
      itemId: _selectedItemId!,
      actualQuantity: actualQty,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      reconciledBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(inventoryItemsProvider);
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
    final actualVal = int.tryParse(_actualQtyCtrl.text.trim()) ?? _recordedQty;
    final discrepancy = actualVal - _recordedQty;

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
                'Stock-Take Reconciliation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reconcile physical stock count against the system record to track shrinkage or surplus.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Divider(height: 20),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              if (widget.preselectedItem != null)
                Text(
                  'Item: ${widget.preselectedItem!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                )
              else
                itemsAsync.when(
                  data: (items) {
                    return DropdownButtonFormField<int>(
                      value: _selectedItemId ?? (items.isNotEmpty ? items.first.id : null),
                      decoration: const InputDecoration(labelText: 'Select Item to Count *'),
                      items: items
                          .map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (Sys: ${i.quantityOnHand})')))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedItemId = val;
                          final match = items.firstWhere((i) => i.id == val);
                          _recordedQty = match.quantityOnHand;
                          _actualQtyCtrl.text = _recordedQty.toString();
                        });
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('System Record', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text('$_recordedQty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 16),
                    Column(
                      children: [
                        const Text('Variance / Shrinkage', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          discrepancy > 0 ? '+$discrepancy (Surplus)' : discrepancy < 0 ? '$discrepancy (Loss)' : '0 (Exact)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: discrepancy < 0 ? Colors.red : discrepancy > 0 ? Colors.green : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _actualQtyCtrl,
                label: 'Actual Counted Quantity *',
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _reasonCtrl,
                label: 'Reconciliation Reason / Note (e.g. Monthly stock audit)',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Reconcile Count', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
