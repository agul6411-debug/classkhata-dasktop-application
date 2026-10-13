/// 3-Step Fee Collection Wizard:
///   Step 1: Search student & pick open voucher
///   Step 2: Enter collection amount & payment mode
///   Step 3: Confirm and print receipt / open WhatsApp link
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
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../students/domain/entities/student_entities.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../domain/entities/fee_entities.dart';
import '../providers/fee_providers.dart';
import 'receipt_dialog.dart';

class FeeCollectionWizard extends ConsumerStatefulWidget {
  const FeeCollectionWizard({super.key});

  @override
  ConsumerState<FeeCollectionWizard> createState() => _FeeCollectionWizardState();
}

class _FeeCollectionWizardState extends ConsumerState<FeeCollectionWizard> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Selected student & voucher
  Student? _selectedStudent;
  FeeVoucher? _selectedVoucher;
  final _searchCtrl = TextEditingController();

  // Step 2: Payment inputs
  final _amountCtrl = TextEditingController();
  String _paymentMode = 'cash';
  final _refCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCollection() async {
    if (_selectedVoucher == null || _selectedStudent == null) return;
    final enteredRupees = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (enteredRupees <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount greater than zero.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(collectFeeUseCaseProvider);

    final result = await useCase(
      userPermissions: currentUser?.permissions ?? {Permission.feesCollect},
      voucherId: _selectedVoucher!.id,
      studentId: _selectedStudent!.id,
      amount: Money.fromRupees(enteredRupees),
      paymentMode: _paymentMode,
      referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (data) {
        ref.invalidate(vouchersListProvider);
        ref.invalidate(defaulterAgingProvider);
        Navigator.of(context).pop();

        final academy = ref.read(academyProfileProvider).valueOrNull;

        // Show official receipt dialog
        showDialog(
          context: context,
          builder: (_) => ReceiptDialog(
            receipt: data.receipt,
            studentName: _selectedStudent!.name,
            guardianPhone: _selectedStudent!.guardianPhone,
            voucherNumber: _selectedVoucher!.voucherNumber,
            rollNumber: _selectedStudent!.rollNumber,
            academyName: academy?.name ?? 'ClassKhata Academy',
            academyPhone: academy?.phone,
            academyAddress: academy?.address,
          ),
        );
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee Collection (Step ${_currentStep + 1} of 3)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
                      ),
                      Text(
                        _stepSubtitle(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],

              // Steps View
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: switch (_currentStep) {
                    0 => _buildStep1SearchStudent(),
                    1 => _buildStep2EnterAmount(),
                    2 => _buildStep3Confirm(),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepSubtitle() => switch (_currentStep) {
        0 => 'Search student and choose open voucher',
        1 => 'Enter payment amount and payment mode',
        _ => 'Confirm payment details to print receipt',
      };

  // ---------------------------------------------------------------------------
  // Step 1: Search Student & Choose Open Voucher
  // ---------------------------------------------------------------------------

  Widget _buildStep1SearchStudent() {
    final studentsAsync = ref.watch(studentsListProvider);
    final vouchersAsync = ref.watch(vouchersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _searchCtrl,
          label: 'Search student name or roll number…',
          prefixIcon: const Icon(Icons.search, size: 20),
          autofocus: true,
          onChanged: (val) => ref.read(studentFilterProvider.notifier).setQuery(val),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: studentsAsync.when(
            data: (students) {
              if (students.isEmpty) {
                return const Center(child: Text('No students found.'));
              }
              return ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final s = students[idx];
                  final isSelected = _selectedStudent?.id == s.id;

                  // Find open vouchers for student
                  final openVouchers = vouchersAsync.maybeWhen(
                    data: (vouchers) => vouchers.where((v) => v.studentId == s.id && !v.isPaidInFull).toList(),
                    orElse: () => <FeeVoucher>[],
                  );

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppColors.accent.withValues(alpha: 0.08),
                    title: Text('${s.name} (${s.rollNumber})', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Guardian: ${s.guardianPhone} • Open bills: ${openVouchers.length}'),
                    trailing: openVouchers.isNotEmpty
                        ? Text(
                            openVouchers.first.balanceRemaining.format(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.overdue),
                          )
                        : const Text('Cleared', style: TextStyle(color: AppColors.paid, fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _selectedStudent = s;
                        if (openVouchers.isNotEmpty) {
                          _selectedVoucher = openVouchers.first;
                          _amountCtrl.text = _selectedVoucher!.balanceRemaining.inRupees.toStringAsFixed(0);
                        } else {
                          _selectedVoucher = null;
                        }
                      });
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            const SizedBox(width: 12),
            PrimaryButton(
              label: 'Next: Amount',
              onPressed: _selectedStudent != null && _selectedVoucher != null
                  ? () => setState(() => _currentStep = 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Enter Amount & Mode
  // ---------------------------------------------------------------------------

  Widget _buildStep2EnterAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Voucher: ${_selectedVoucher?.voucherNumber ?? ""}'),
              Text(
                'Total Due: ${_selectedVoucher?.balanceRemaining.format() ?? ""}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.overdue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _amountCtrl,
          label: 'Payment Amount (Rs.) *',
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _paymentMode,
          decoration: const InputDecoration(labelText: 'Payment Mode *'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'bank', child: Text('Bank Transfer / Deposit')),
            DropdownMenuItem(value: 'online', child: Text('Online / Mobile Wallet')),
          ],
          onChanged: (val) => setState(() => _paymentMode = val ?? 'cash'),
        ),
        if (_paymentMode != 'cash') ...[
          const SizedBox(height: 12),
          AppTextField(controller: _refCtrl, label: 'Reference / Transaction ID'),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Back'),
            ),
            PrimaryButton(
              label: 'Next: Confirm',
              onPressed: () {
                final val = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                if (val > 0) {
                  setState(() => _currentStep = 2);
                } else {
                  setState(() => _errorMessage = 'Amount must be greater than zero.');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Review & Confirm
  // ---------------------------------------------------------------------------

  Widget _buildStep3Confirm() {
    final enteredRupees = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final enteredMoney = Money.fromRupees(enteredRupees);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.paidBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.paid.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                enteredMoney.format(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.paid,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Payment Confirmation', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _summaryRow('Student Name', _selectedStudent?.name ?? ''),
        _summaryRow('Roll Number', _selectedStudent?.rollNumber ?? ''),
        _summaryRow('Voucher Number', _selectedVoucher?.voucherNumber ?? ''),
        _summaryRow('Payment Mode', _paymentMode.toUpperCase()),
        if (_refCtrl.text.trim().isNotEmpty) _summaryRow('Ref Number', _refCtrl.text.trim()),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back'),
            ),
            PrimaryButton(
              label: 'Confirm & Generate Receipt',
              icon: Icons.print,
              isLoading: _isLoading,
              onPressed: _submitCollection,
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
