/// Stock-Take Physical Reconciliation Modal Dialog (Strictly NO Barcodes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

class StockReconcileDialog extends ConsumerStatefulWidget {
  const StockReconcileDialog({super.key});

  @override
  ConsumerState<StockReconcileDialog> createState() => _StockReconcileDialogState();
}

class _StockReconcileDialogState extends ConsumerState<StockReconcileDialog> {
  final _actualQtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  int? _selectedItemId;
  int _currentRecordedQty = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successNotice;

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
      _successNotice = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(stockReconciliationUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
      itemId: _selectedItemId!,
      actualQuantity: actualQty,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      reconciledBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (data) {
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryMovementsProvider);
        ref.invalidate(stockValuationProvider);

        if (data.requiresApproval) {
          setState(() {
            _isLoading = false;
            _successNotice =
                'Discrepancy exceeds threshold. An approval request (#${data.approvalId}) has been escalated to the Maker-Checker queue.';
          });
        } else {
          Navigator.of(context).pop(true);
        }
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

    final actualParsed = int.tryParse(_actualQtyCtrl.text.trim());
    final discrepancy = actualParsed != null ? actualParsed - _currentRecordedQty : 0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Physical Stock-Take Audit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.heading),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter actual physical count. Variances are posted as audit adjustments. Large discrepancies require Maker-Checker sign-off.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              if (_successNotice != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successNotice!,
                          style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Item Selector
              itemsAsync.when(
                data: (items) => DropdownButtonFormField<int>(
                  initialValue: _selectedItemId,
                  decoration: const InputDecoration(
                    labelText: 'Select Inventory Item *',
                    border: OutlineInputBorder(),
                  ),
                  items: items
                      .map((i) => DropdownMenuItem(
                            value: i.id,
                            child: Text('${i.name} (Recorded: ${i.quantityOnHand} ${i.unit})'),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final it = items.firstWhere((x) => x.id == id);
                    setState(() {
                      _selectedItemId = id;
                      _currentRecordedQty = it.quantityOnHand;
                      _actualQtyCtrl.text = it.quantityOnHand.toString();
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Failed to load items: $err'),
              ),
              const SizedBox(height: 16),

              // Count Entry & Discrepancy Display
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _actualQtyCtrl,
                      label: 'Actual Physical Count *',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: discrepancy == 0
                            ? AppColors.inputFill
                            : discrepancy < 0
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: discrepancy == 0
                              ? AppColors.border
                              : discrepancy < 0
                                  ? Colors.red.shade300
                                  : Colors.green.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Variance / Shrinkage', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            discrepancy > 0 ? '+$discrepancy (Surplus)' : '$discrepancy (Deficit)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: discrepancy == 0
                                  ? AppColors.textPrimary
                                  : discrepancy < 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _reasonCtrl,
                label: 'Audit Reason / Shrinkage Notes',
                hint: 'e.g., Annual physical audit, damaged in store, breakage',
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
                    label: 'Post Reconciliation',
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
