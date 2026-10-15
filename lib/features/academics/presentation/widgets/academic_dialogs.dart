/// Dialogs for managing Academic Sessions, School Classes, and Class Sections.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart';
import '../../domain/entities/academic_entities.dart';
import '../providers/academic_providers.dart';

// ---------------------------------------------------------------------------
// 1. Create Academic Session Dialog
// ---------------------------------------------------------------------------

class CreateSessionDialog extends ConsumerStatefulWidget {
  const CreateSessionDialog({super.key});

  @override
  ConsumerState<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog> {
  final _nameCtrl = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().year + 1}');
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
    return Dialog(
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
                'New Academic Session',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context)),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _nameCtrl,
                label: 'Academic Session (e.g. 2026-2027) *',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Set as Active Academic Session'),
                subtitle: const Text('New student enrollments will default to this session.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                value: _isCurrent,
                onChanged: (val) => setState(() => _isCurrent = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Save Session', isLoading: _isLoading, onPressed: _submit),
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
// 2. Manage Academic Sessions Modal
// ---------------------------------------------------------------------------

class ManageSessionsDialog extends ConsumerWidget {
  const ManageSessionsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicDataAsync = ref.watch(academicDataProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Academic Sessions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Session'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const CreateSessionDialog(),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: academicDataAsync.when(
                  data: (data) {
                    if (data.sessions.isEmpty) {
                      return const Center(child: Text('No academic sessions created yet.'));
                    }
                    return ListView.separated(
                      itemCount: data.sessions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final session = data.sessions[i];
                        return ListTile(
                          title: Row(
                            children: [
                              Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (session.isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.paidBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('ACTIVE', style: TextStyle(color: AppColors.paid, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Period: ${session.startDate.day}/${session.startDate.month}/${session.startDate.year} - ${session.endDate.day}/${session.endDate.month}/${session.endDate.year}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: session.isCurrent
                              ? const Icon(Icons.check_circle, color: AppColors.paid, size: 22)
                              : TextButton(
                                  child: const Text('Make Active'),
                                  onPressed: () async {
                                    final setUseCase = ref.read(setCurrentSessionUseCaseProvider);
                                    await setUseCase(session.id);
                                    ref.invalidate(academicDataProvider);
                                  },
                                ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Create Class / Grade Dialog
// ---------------------------------------------------------------------------

class CreateCourseDialog extends ConsumerStatefulWidget {
  const CreateCourseDialog({super.key});

  @override
  ConsumerState<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

typedef CreateClassDialog = CreateCourseDialog;

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
      setState(() => _errorMessage = 'Class name is required.');
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
        ref.invalidate(dashboardKpisProvider);
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add School Class / Grade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context))),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _nameCtrl,
                label: 'Class Name (e.g. Class 9, Grade 10, Matric Science) *',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _codeCtrl,
                label: 'Class Code / Level (e.g. 9, 10, CL-09)',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descCtrl,
                label: 'Description / Curriculum Notes (Optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Save Class', isLoading: _isLoading, onPressed: _submit),
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
// 4. Create Section Dialog
// ---------------------------------------------------------------------------

class CreateBatchDialog extends ConsumerStatefulWidget {

  const CreateBatchDialog({
    super.key,
    this.initialCourseId,
  });
  final int? initialCourseId;

  @override
  ConsumerState<CreateBatchDialog> createState() => _CreateBatchDialogState();
}

typedef CreateSectionDialog = CreateBatchDialog;

class _CreateBatchDialogState extends ConsumerState<CreateBatchDialog> {
  final _nameCtrl = TextEditingController(text: 'Section A');
  final _instructorCtrl = TextEditingController();
  final _timingCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '3500');
  final _dueDayCtrl = TextEditingController(text: '10');

  int? _selectedSessionId;
  int? _selectedCourseId;
  String? _selectedTeacherName;
  bool _isCustomTeacher = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
  }

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
      setState(() => _errorMessage = 'Please select both session and class.');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Section name is required (e.g. Section A).');
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

    final instructor = _isCustomTeacher
        ? _instructorCtrl.text.trim()
        : (_selectedTeacherName ?? (_instructorCtrl.text.trim().isEmpty ? null : _instructorCtrl.text.trim()));

    final result = await useCase(
      sessionId: _selectedSessionId!,
      courseId: _selectedCourseId!,
      name: name,
      instructorName: (instructor != null && instructor.isNotEmpty) ? instructor : null,
      timing: _timingCtrl.text.trim().isEmpty ? null : _timingCtrl.text.trim(),
      monthlyFee: Money.fromRupees(feeRupees),
      dueDay: dueDay,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(academicDataProvider);
        ref.invalidate(dashboardKpisProvider);
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Class Section', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context))),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              academicDataAsync.when(
                data: (data) {
                  // Ensure default selections
                  final currentSession = data.currentSession;
                  _selectedSessionId ??= currentSession?.id ?? (data.sessions.isNotEmpty ? data.sessions.first.id : null);
                  _selectedCourseId ??= widget.initialCourseId ?? (data.courses.isNotEmpty ? data.courses.first.id : null);

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedSessionId,
                          decoration: const InputDecoration(labelText: 'Academic Session *'),
                          items: data.sessions.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (val) => setState(() => _selectedSessionId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedCourseId,
                          decoration: const InputDecoration(labelText: 'School Class *'),
                          items: data.courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (val) => setState(() => _selectedCourseId = val),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load academic options'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _nameCtrl,
                label: 'Section Name (e.g. Section A, Rose, Morning) *',
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ref.watch(staffListProvider).when(
                          data: (staffList) {
                            final activeTeachers = staffList.where((s) => s.status.name.toLowerCase() == 'active').toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String?>(
                                  value: _selectedTeacherName,
                                  decoration: const InputDecoration(labelText: 'Class Teacher (Staff List)'),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('None (No Teacher Assigned)', overflow: TextOverflow.ellipsis),
                                    ),
                                    ...activeTeachers.map((s) => DropdownMenuItem<String?>(
                                          value: s.name,
                                          child: Text('${s.name} (${s.designation})', overflow: TextOverflow.ellipsis),
                                        )),
                                    const DropdownMenuItem<String?>(
                                      value: '__CUSTOM__',
                                      child: Text('+ Custom / Unregistered Teacher', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == '__CUSTOM__') {
                                        _isCustomTeacher = true;
                                        _selectedTeacherName = '__CUSTOM__';
                                      } else {
                                        _isCustomTeacher = false;
                                        _selectedTeacherName = val;
                                        _instructorCtrl.text = val ?? '';
                                      }
                                    });
                                  },
                                ),
                                if (_isCustomTeacher) ...[
                                  const SizedBox(height: 8),
                                  AppTextField(
                                    controller: _instructorCtrl,
                                    label: 'Teacher Full Name',
                                    autofocus: true,
                                  ),
                                ],
                              ],
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => AppTextField(
                            controller: _instructorCtrl,
                            label: 'Class Teacher / In-charge',
                          ),
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _timingCtrl,
                      label: 'Room / Hall (e.g. Room 10)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _feeCtrl,
                      label: 'Monthly Tuition Fee (Rs.) *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _dueDayCtrl,
                      label: 'Fee Due Day of Month (1 - 28) *',
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
                  PrimaryButton(label: 'Save Section', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
