/// Add Staff Member & Initial Salary Structure Dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/payroll_providers.dart';

class StaffFormDialog extends ConsumerStatefulWidget {
  const StaffFormDialog({super.key});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _baseAmountCtrl = TextEditingController(text: '30000');
  final _allowancesCtrl = TextEditingController(text: '0');
  final _deductionsCtrl = TextEditingController(text: '0');

  String _structureType = 'fixed';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _designationCtrl.dispose();
    _cnicCtrl.dispose();
    _baseAmountCtrl.dispose();
    _allowancesCtrl.dispose();
    _deductionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final designation = _designationCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || designation.isEmpty) {
      setState(() => _errorMessage = 'Name, phone, and designation are required.');
      return;
    }

    final baseRupees = double.tryParse(_baseAmountCtrl.text.trim()) ?? 0;
    final allowRupees = double.tryParse(_allowancesCtrl.text.trim()) ?? 0;
    final dedRupees = double.tryParse(_deductionsCtrl.text.trim()) ?? 0;

    if (baseRupees <= 0) {
      setState(() => _errorMessage = 'Base salary must be greater than zero.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userId = currentUser?.id ?? 1;

    final createStaffUseCase = ref.read(createStaffMemberUseCaseProvider);
    final repo = ref.read(payrollRepositoryProvider);

    final staffRes = await createStaffUseCase(
      name: name,
      phone: phone,
      designation: designation,
      cnic: _cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim(),
      createdBy: userId,
    );

    if (!mounted) return;

    if (staffRes.isFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = staffRes.fold(onSuccess: (_) => '', onFailure: (f) => f.message);
      });
      return;
    }

    final newStaff = staffRes.fold(onSuccess: (s) => s, onFailure: (_) => throw Exception());

    // Assign salary structure
    final structureRes = await repo.setSalaryStructure(
      staffId: newStaff.id,
      structureType: _structureType,
      baseAmount: Money.fromRupees(baseRupees),
      allowances: Money.fromRupees(allowRupees),
      deductions: Money.fromRupees(dedRupees),
      createdBy: userId,
    );

    if (!mounted) return;

    structureRes.fold(
      onSuccess: (_) {
        ref.invalidate(staffListProvider);
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
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Staff Member',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context)),
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
                    child: AppTextField(
                      controller: _nameCtrl,
                      label: 'Full Name *',
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number *',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _designationCtrl,
                      label: 'Designation / Role *',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _cnicCtrl,
                      label: 'CNIC / National ID (Optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Salary Structure',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _structureType,
                      decoration: const InputDecoration(labelText: 'Salary Basis'),
                      items: const [
                        DropdownMenuItem(value: 'fixed', child: Text('Fixed Monthly')),
                        DropdownMenuItem(value: 'per_class', child: Text('Per Class / Lecture')),
                        DropdownMenuItem(value: 'per_hour', child: Text('Per Hour')),
                      ],
                      onChanged: (val) => setState(() => _structureType = val ?? 'fixed'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _baseAmountCtrl,
                      label: 'Base Pay (Rs.) *',
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
                      controller: _allowancesCtrl,
                      label: 'Allowances (Rs.)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _deductionsCtrl,
                      label: 'Deductions (Rs.)',
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
                  PrimaryButton(label: 'Save Staff Member', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
