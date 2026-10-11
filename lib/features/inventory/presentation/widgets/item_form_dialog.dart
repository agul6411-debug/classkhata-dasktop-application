/// Add Inventory Item Modal Dialog (Strictly NO Barcodes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
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
    final reorderLevel = int.tryParse(_reorderCtrl.text.trim()) ?? 5;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(createInventoryItemUseCaseProvider);

    final res = await useCase(
      categoryId: _selectedCategoryId ?? 1,
      name: name,
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      initialQuantity: initialQty,
      unitCost: Money.fromRupees(costRupees),
      reorderLevel: reorderLevel,
      createdBy: currentUser?.id ?? 1,
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
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Inventory Item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              categoriesAsync.when(
                data: (cats) {
                  return DropdownButtonFormField<int>(
                    value: _selectedCategoryId ?? (cats.isNotEmpty ? cats.first.id : null),
                    decoration: const InputDecoration(labelText: 'Category *'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _nameCtrl,
                label: 'Item Name / Description *',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _unitCtrl,
                      label: 'Unit of Measure (e.g. pcs, box, pack)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _qtyCtrl,
                      label: 'Initial Stock Count',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _costCtrl,
                      label: 'Unit Cost (Rs.)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _reorderCtrl,
                      label: 'Reorder Alert Level',
                      keyboardType: TextInputType.number,
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
                  PrimaryButton(label: 'Save Item', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
