/// Dialog for student registration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/student_entities.dart';
import '../providers/student_providers.dart';

class StudentFormDialog extends ConsumerStatefulWidget {
  const StudentFormDialog({super.key});

  @override
  ConsumerState<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends ConsumerState<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _rollNumberCtrl = TextEditingController();

  int? _selectedBatchId;
  int? _selectedFamilyId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _rollNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBatchId == null) {
      setState(() => _errorMessage = 'Please select a batch.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(registerStudentUseCaseProvider);

    final result = await useCase(
      name: _nameCtrl.text.trim(),
      batchId: _selectedBatchId!,
      guardianPhone: _guardianPhoneCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      familyId: _selectedFamilyId,
      customRollNumber: _rollNumberCtrl.text.trim().isEmpty ? null : _rollNumberCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (student) {
        ref.invalidate(studentsListProvider);
        Navigator.of(context).pop(student);
      },
      onFailure: (f) {
        setState(() {
          _isLoading = false;
          _errorMessage = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final academicDataAsync = ref.watch(academicDataProvider);
    final familiesAsync = ref.watch(familiesListProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Register New Student',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
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
                        label: 'Student Name *',
                        autofocus: true,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _guardianPhoneCtrl,
                        label: 'Guardian Phone *',
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Guardian phone is required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _phoneCtrl,
                        label: 'Student Phone (Optional)',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _emailCtrl,
                        label: 'Email (Optional)',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: academicDataAsync.when(
                        data: (data) {
                          if (data.batches.isEmpty) {
                            return const Text('No batches available. Create a batch first.',
                                style: TextStyle(color: AppColors.overdue, fontSize: 13));
                          }
                          return DropdownButtonFormField<int>(
                            value: _selectedBatchId,
                            decoration: const InputDecoration(labelText: 'Batch / Section *'),
                            items: data.batches
                                .map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text('${b.name} (${b.monthlyFee.format()}/mo)'),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedBatchId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Failed to load batches'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: familiesAsync.when(
                        data: (families) {
                          return DropdownButtonFormField<int?>(
                            value: _selectedFamilyId,
                            decoration: const InputDecoration(labelText: 'Family / Sibling Link'),
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(value: null, child: Text('None (Individual)')),
                              ...families.map((f) => DropdownMenuItem<int?>(
                                    value: f.id,
                                    child: Text('${f.familyCode} - ${f.guardianName}'),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedFamilyId = val),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _rollNumberCtrl,
                  label: 'Custom Roll Number (Leave empty for auto-generated)',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Register Student',
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
