/// Stock Movement Modal Dialog (Strictly NO Barcodes).
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
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  int? _selectedItemId;
  late String _movementType;
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
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(recordStockMovementUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
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
        ref.invalidate(stockValuationProvider);
        ref.invalidate(lowStockAlertsProvider);
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
                  Text(
                    _movementType == 'in' ? 'Record Stock In' : 'Record Stock Out',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.heading),
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

              // Movement Type Toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'in',
                    label: Text('Stock In (Receive)'),
                    icon: Icon(Icons.arrow_downward, size: 16),
                  ),
                  ButtonSegment(
                    value: 'out',
                    label: Text('Stock Out (Issue)'),
                    icon: Icon(Icons.arrow_upward, size: 16),
                  ),
                ],
                selected: {_movementType},
                onSelectionChanged: (set) => setState(() => _movementType = set.first),
              ),
              const SizedBox(height: 16),

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
                            child: Text('${i.name} (Available: ${i.quantityOnHand} ${i.unit})'),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final it = items.firstWhere((x) => x.id == id);
                    setState(() {
                      _selectedItemId = id;
                      _costCtrl.text = it.unitCost.inRupees.toString();
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Failed to load items: $err'),
              ),
              const SizedBox(height: 14),

              // Quantity & Unit Cost
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _qtyCtrl,
                      label: 'Quantity *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _costCtrl,
                      label: 'Unit Cost (PKR)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reason
              AppTextField(
                controller: _reasonCtrl,
                label: 'Reason / Purpose *',
                hint: _movementType == 'in'
                    ? 'e.g. Delivery from supplier, donation'
                    : 'e.g. Issued to Science Lab, Exam Hall distribution',
              ),
              const SizedBox(height: 14),

              // Reference Number
              AppTextField(
                controller: _refCtrl,
                label: 'Invoice / PO Reference #',
                hint: 'Optional reference',
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
                    label: 'Save Movement',
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
