/// Add Inventory Item Modal Dialog (Strictly NO Barcodes).
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

class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({super.key});

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _qtyCtrl = TextEditingController(text: '0');
  final _costCtrl = TextEditingController(text: '0');
  final _saleCtrl = TextEditingController(text: '0');
  final _reorderCtrl = TextEditingController(text: '5');
  int? _selectedCategoryId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _saleCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Item name is required.');
      return;
    }

    final initialQty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final costRupees = double.tryParse(_costCtrl.text.trim()) ?? 0;
    final saleRupees = double.tryParse(_saleCtrl.text.trim()) ?? 0;
    final reorderLevel = int.tryParse(_reorderCtrl.text.trim()) ?? 5;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(createInventoryItemUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
      categoryId: _selectedCategoryId ?? 1,
      name: name,
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      initialQuantity: initialQty,
      unitCost: Money.fromRupees(costRupees),
      sellingPrice: Money.fromRupees(saleRupees),
      reorderLevel: reorderLevel,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(inventoryItemsProvider);
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
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);

    return Dialog(
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
                    'Add Inventory Item',
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

              // Category Selector
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : null),
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (id) => setState(() => _selectedCategoryId = id),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Failed to load categories: $err'),
              ),
              const SizedBox(height: 14),

              // Item Name
              AppTextField(
                controller: _nameCtrl,
                label: 'Item Name *',
                hint: 'e.g. Mathematics Textbook 9th, Blue Ballpoint Pen',
              ),
              const SizedBox(height: 14),

              // Unit of Measure & Initial Quantity
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _unitCtrl,
                      label: 'Unit of Measure *',
                      hint: 'pcs, box, pack, ream',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _qtyCtrl,
                      label: 'Opening Stock Count',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Unit Cost & Selling Price
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _costCtrl,
                      label: 'Purchase Cost (PKR) *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _saleCtrl,
                      label: 'Selling Price (PKR)',
                      hint: 'Optional charge rate',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Low-Stock Threshold
              AppTextField(
                controller: _reorderCtrl,
                label: 'Low-Stock Alert Level',
                hint: 'Threshold count for dashboard alert (default 5)',
                keyboardType: TextInputType.number,
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
                    label: 'Save Item',
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
