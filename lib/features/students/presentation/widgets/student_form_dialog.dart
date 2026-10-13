/// Dialog for student registration with authentic school hierarchy (Class -> Section).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/domain/entities/academic_entities.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../providers/student_providers.dart';

class StudentFormDialog extends ConsumerStatefulWidget {

  const StudentFormDialog({super.key, this.initialBatchId});
  final int? initialBatchId;

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

  int? _selectedClassId;
  int? _selectedBatchId;
  int? _selectedFamilyId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

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
      setState(() => _errorMessage = 'Please select a Class and Section for enrollment.');
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
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      familyId: _selectedFamilyId,
      customRollNumber: _rollNumberCtrl.text.trim().isEmpty ? null : _rollNumberCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (student) {
        ref.read(studentListVersionProvider.notifier).state++;
        ref.invalidate(studentsListProvider);
        ref.invalidate(dashboardKpisProvider);
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

    // Pre-select initial batch and its class if requested
    academicDataAsync.whenData((data) {
      if (!_initialized) {
        _initialized = true;
        if (widget.initialBatchId != null) {
          _selectedBatchId = widget.initialBatchId;
          final batch = data.batches.where((b) => b.id == widget.initialBatchId).firstOrNull;
          if (batch != null) {
            _selectedClassId = batch.courseId;
          }
        }
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                    Text(
                      'Register New Student',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingCol(context),
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
                        label: 'Student Full Name *',
                        autofocus: true,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _guardianPhoneCtrl,
                        label: 'Guardian Phone (WhatsApp) *',
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

                // School Class & Section Hierarchy Dropdowns
                academicDataAsync.when(
                  data: (data) {
                    final availableClasses = data.courses;
                    final availableSections = _selectedClassId != null
                        ? data.getSectionsForClass(_selectedClassId!)
                        : <Batch>[];

                    return Row(
                      children: [
                        // Class dropdown
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedClassId,
                            decoration: const InputDecoration(labelText: 'School Class / Grade *'),
                            items: availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClassId = val;
                                final sections = val != null ? data.getSectionsForClass(val) : <Batch>[];
                                _selectedBatchId = sections.length == 1 ? sections.first.id : null;
                              });
                            },
                            validator: (v) => v == null ? 'Class is required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Section dropdown
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedBatchId,
                            decoration: InputDecoration(
                              labelText: 'Section *',
                              helperText: _selectedClassId == null
                                  ? 'Select class first'
                                  : (availableSections.isEmpty ? 'No sections found' : null),
                            ),
                            items: availableSections.map((b) {
                              return DropdownMenuItem(
                                value: b.id,
                                child: Text('${b.name} (${b.monthlyFee.format()}/mo)'),
                              );
                            }).toList(),
                            onChanged: _selectedClassId == null || availableSections.isEmpty
                                ? null
                                : (val) => setState(() => _selectedBatchId = val),
                            validator: (v) => v == null ? 'Section is required' : null,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load academic options', style: TextStyle(color: AppColors.overdue)),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _rollNumberCtrl,
                        label: 'Admission / Roll No. (Optional)',
                        hint: 'Auto-generated if empty',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: familiesAsync.when(
                        data: (families) {
                          return DropdownButtonFormField<int?>(
                            initialValue: _selectedFamilyId,
                            decoration: const InputDecoration(labelText: 'Family Link (Siblings)'),
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(child: Text('None (Individual)')),
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
