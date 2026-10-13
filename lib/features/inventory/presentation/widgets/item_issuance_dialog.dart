/// Item Issuance Modal Dialog (Issue to Student or Staff with optional Fee Voucher charge).
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
import '../../../fees/domain/entities/fee_entities.dart';
import '../../../fees/presentation/providers/fee_providers.dart';
import '../../../payroll/domain/entities/payroll_entities.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';
import '../../../students/domain/entities/student_entities.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../providers/inventory_providers.dart';

class ItemIssuanceDialog extends ConsumerStatefulWidget {
  const ItemIssuanceDialog({super.key});

  @override
  ConsumerState<ItemIssuanceDialog> createState() => _ItemIssuanceDialogState();
}

class _ItemIssuanceDialogState extends ConsumerState<ItemIssuanceDialog> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();
  int? _selectedItemId;
  String _recipientType = 'student'; // 'student' or 'staff'
  int? _selectedStudentId;
  int? _selectedStaffId;
  int? _selectedFeeVoucherId;
  bool _chargeVoucher = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedItemId == null) {
      setState(() => _errorMessage = 'Please select an item.');
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be greater than zero.');
      return;
    }

    final priceRupees = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Issuance reason is required.');
      return;
    }

    if (_recipientType == 'student' && _selectedStudentId == null) {
      setState(() => _errorMessage = 'Please select a student.');
      return;
    }
    if (_recipientType == 'staff' && _selectedStaffId == null) {
      setState(() => _errorMessage = 'Please select a staff member.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userPermissions = currentUser?.permissions ?? Permission.values.toSet();

    final useCase = ref.read(issueItemUseCaseProvider);

    final res = await useCase(
      userPermissions: userPermissions,
      itemId: _selectedItemId!,
      quantity: qty,
      unitPrice: Money.fromRupees(priceRupees),
      recipientType: _recipientType,
      studentId: _recipientType == 'student' ? _selectedStudentId : null,
      staffId: _recipientType == 'staff' ? _selectedStaffId : null,
      feeVoucherId: _chargeVoucher ? _selectedFeeVoucherId : null,
      reason: reason,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        ref.invalidate(itemIssuancesProvider);
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryMovementsProvider);
        ref.invalidate(stockValuationProvider);
        if (_chargeVoucher) {
          ref.invalidate(vouchersListProvider);
        }
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
    final studentsAsync = ref.watch(studentsListProvider);
    final staffAsync = ref.watch(staffListProvider);
    final vouchersAsync = ref.watch(vouchersListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                      'Issue Inventory Item',
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

                // Item Selector
                itemsAsync.when(
                  data: (items) => DropdownButtonFormField<int>(
                    initialValue: _selectedItemId,
                    decoration: const InputDecoration(
                      labelText: 'Select Item to Issue *',
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
                        _priceCtrl.text = it.sellingPrice.paisa > 0
                            ? it.sellingPrice.inRupees.toString()
                            : it.unitCost.inRupees.toString();
                      });
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Failed to load items: $err'),
                ),
                const SizedBox(height: 14),

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
                        controller: _priceCtrl,
                        label: 'Charge Rate (PKR)',
                        hint: '0 for free issue',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Recipient Type Selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'student', label: Text('Issue to Student')),
                    ButtonSegment(value: 'staff', label: Text('Issue to Staff / Teacher')),
                  ],
                  selected: {_recipientType},
                  onSelectionChanged: (set) => setState(() => _recipientType = set.first),
                ),
                const SizedBox(height: 14),

                // Student / Staff Selector
                if (_recipientType == 'student')
                  studentsAsync.when(
                    data: (List<Student> students) => DropdownButtonFormField<int>(
                      initialValue: _selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'Select Student *',
                        border: OutlineInputBorder(),
                      ),
                      items: students
                          .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.rollNumber})')))
                          .toList(),
                      onChanged: (id) => setState(() => _selectedStudentId = id),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (Object err, _) => Text('Error loading students: $err'),
                  )
                else
                  staffAsync.when(
                    data: (List<StaffMember> staff) => DropdownButtonFormField<int>(
                      initialValue: _selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Select Staff Member *',
                        border: OutlineInputBorder(),
                      ),
                      items: staff
                          .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.designation})')))
                          .toList(),
                      onChanged: (id) => setState(() => _selectedStaffId = id),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (Object err, _) => Text('Error loading staff: $err'),
                  ),
                const SizedBox(height: 14),

                // Fee Voucher Charging Toggle (If issued to student)
                if (_recipientType == 'student') ...[
                  CheckboxListTile(
                    title: const Text('Charge to Student Fee Voucher', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Atomically adds this item cost to the pending fee voucher total due',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    value: _chargeVoucher,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _chargeVoucher = val ?? false),
                  ),
                  if (_chargeVoucher)
                    vouchersAsync.when(
                      data: (List<FeeVoucher> vouchers) {
                        final studentVouchers = _selectedStudentId != null
                            ? vouchers.where((v) => v.studentId == _selectedStudentId).toList()
                            : vouchers;
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedFeeVoucherId,
                          decoration: const InputDecoration(
                            labelText: 'Select Fee Voucher to Charge *',
                            border: OutlineInputBorder(),
                          ),
                          items: studentVouchers
                              .map((v) => DropdownMenuItem(
                                    value: v.id,
                                    child: Text('${v.voucherNumber} (${v.monthYear}) - Due: ${v.totalDue.format()}'),
                                  ))
                              .toList(),
                          onChanged: (id) => setState(() => _selectedFeeVoucherId = id),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (Object err, _) => Text('Error loading vouchers: $err'),
                    ),
                  const SizedBox(height: 14),
                ],

                AppTextField(
                  controller: _reasonCtrl,
                  label: 'Purpose / Reason *',
                  hint: 'e.g. Science practical syllabus manual, uniform distribution',
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
                      label: 'Issue Item',
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
