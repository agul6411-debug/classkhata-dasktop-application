/// Dialogs for adding Sessions, Courses, and Batches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/academic_providers.dart';

// ---------------------------------------------------------------------------
// Create Session Dialog
// ---------------------------------------------------------------------------

class CreateSessionDialog extends ConsumerStatefulWidget {
  const CreateSessionDialog({super.key});

  @override
  ConsumerState<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog> {
  final _nameCtrl = TextEditingController(text: '2026-2027');
  bool _isCurrent = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Session name is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(createSessionUseCaseProvider);

    final now = DateTime.now();
    final result = await useCase(
      name: name,
      startDate: now,
      endDate: now.add(const Duration(days: 365)),
      isCurrent: _isCurrent,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(academicDataProvider);
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
    return _dialogWrapper(
      title: 'New Academic Session',
      errorMessage: _errorMessage,
      children: [
        AppTextField(
          controller: _nameCtrl,
          label: 'Session Name (e.g. 2026-2027)',
          autofocus: true,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Mark as Current Session'),
          value: _isCurrent,
          onChanged: (val) => setState(() => _isCurrent = val),
          contentPadding: EdgeInsets.zero,
        ),
      ],
      isLoading: _isLoading,
      onSubmit: _submit,
    );
  }

  Widget _dialogWrapper({
    required String title,
    required String? errorMessage,
    required List<Widget> children,
    required bool isLoading,
    required VoidCallback onSubmit,
  }) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (errorMessage != null) ...[
                ErrorBanner(message: errorMessage),
                const SizedBox(height: 12),
              ],
              ...children,
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Save', isLoading: isLoading, onPressed: onSubmit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Course Dialog
// ---------------------------------------------------------------------------

class CreateCourseDialog extends ConsumerStatefulWidget {
  const CreateCourseDialog({super.key});

  @override
  ConsumerState<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends ConsumerState<CreateCourseDialog> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Course name is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(createCourseUseCaseProvider);

    final result = await useCase(
      name: name,
      code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(academicDataProvider);
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Course / Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading)),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              AppTextField(controller: _nameCtrl, label: 'Course Name (e.g. Matric Science) *', autofocus: true),
              const SizedBox(height: 12),
              AppTextField(controller: _codeCtrl, label: 'Course Code (Optional)'),
              const SizedBox(height: 12),
              AppTextField(controller: _descCtrl, label: 'Description (Optional)', maxLines: 2),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Save Course', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Batch Dialog
// ---------------------------------------------------------------------------

class CreateBatchDialog extends ConsumerStatefulWidget {
  const CreateBatchDialog({super.key});

  @override
  ConsumerState<CreateBatchDialog> createState() => _CreateBatchDialogState();
}

class _CreateBatchDialogState extends ConsumerState<CreateBatchDialog> {
  final _nameCtrl = TextEditingController();
  final _instructorCtrl = TextEditingController();
  final _timingCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '3000');
  final _dueDayCtrl = TextEditingController(text: '10');

  int? _selectedSessionId;
  int? _selectedCourseId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instructorCtrl.dispose();
    _timingCtrl.dispose();
    _feeCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedSessionId == null || _selectedCourseId == null) {
      setState(() => _errorMessage = 'Please select both session and course.');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Batch name is required.');
      return;
    }

    final feeRupees = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    final dueDay = int.tryParse(_dueDayCtrl.text.trim()) ?? 10;

    if (dueDay < 1 || dueDay > 28) {
      setState(() => _errorMessage = 'Fee due day must be between 1 and 28.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(createBatchUseCaseProvider);

    final result = await useCase(
      sessionId: _selectedSessionId!,
      courseId: _selectedCourseId!,
      name: name,
      instructorName: _instructorCtrl.text.trim(),
      timing: _timingCtrl.text.trim(),
      monthlyFee: Money.fromRupees(feeRupees),
      dueDay: dueDay,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(academicDataProvider);
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add New Batch / Section', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading)),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              academicDataAsync.when(
                data: (data) => Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedSessionId ?? (data.sessions.isNotEmpty ? data.sessions.first.id : null),
                        decoration: const InputDecoration(labelText: 'Session *'),
                        items: data.sessions.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _selectedSessionId = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedCourseId ?? (data.courses.isNotEmpty ? data.courses.first.id : null),
                        decoration: const InputDecoration(labelText: 'Course *'),
                        items: data.courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (val) => setState(() => _selectedCourseId = val),
                      ),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load academic options'),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _nameCtrl, label: 'Batch Name (e.g. Morning-A) *'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AppTextField(controller: _instructorCtrl, label: 'Instructor (Optional)')),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _timingCtrl, label: 'Timing (e.g. 9-11 AM)')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _feeCtrl,
                      label: 'Monthly Fee (Rs.) *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _dueDayCtrl,
                      label: 'Fee Due Day (1 - 28) *',
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
                  PrimaryButton(label: 'Save Batch', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
