/// Bulk voucher generation modal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/domain/entities/academic_entities.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/fee_providers.dart';

class VoucherGenerateDialog extends ConsumerStatefulWidget {
  const VoucherGenerateDialog({super.key});

  @override
  ConsumerState<VoucherGenerateDialog> createState() => _VoucherGenerateDialogState();
}

class _VoucherGenerateDialogState extends ConsumerState<VoucherGenerateDialog> {
  int? _selectedBatchId;
  String _monthYear = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_selectedBatchId == null) {
      setState(() => _errorMessage = 'Please select a Class & Section.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(generateVouchersUseCaseProvider);

    final result = await useCase(
      userPermissions: currentUser?.permissions ?? {Permission.feesVoucherGenerate},
      batchId: _selectedBatchId!,
      monthYear: _monthYear,
      dueDate: _dueDate,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (count) {
        ref.invalidate(vouchersListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated $count voucher(s) successfully!')),
        );
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
    final academicDataAsync = ref.watch(academicDataProvider);

    return Dialog(
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
                'Generate Monthly Vouchers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context)),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              academicDataAsync.when(
                data: (data) => DropdownButtonFormField<int>(
                  initialValue: _selectedBatchId,
                  decoration: const InputDecoration(labelText: 'Target Class & Section *'),
                  items: data.batches
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${data.getFullSectionName(b.id)} (${b.monthlyFee.format()})'),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBatchId = val),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load classes & sections'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _monthYear,
                decoration: const InputDecoration(labelText: 'Billing Month (YYYY-MM) *'),
                onChanged: (val) => _monthYear = val,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date', style: TextStyle(fontSize: 14)),
                subtitle: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Generate Vouchers', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
