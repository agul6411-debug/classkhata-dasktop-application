/// Bulk student import dialog with CSV/Excel text parsing and validation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/student_entities.dart';
import '../providers/student_providers.dart';

class StudentImportDialog extends ConsumerStatefulWidget {
  const StudentImportDialog({super.key});

  @override
  ConsumerState<StudentImportDialog> createState() => _StudentImportDialogState();
}

class _StudentImportDialogState extends ConsumerState<StudentImportDialog> {
  final _inputCtrl = TextEditingController();
  int? _selectedBatchId;
  bool _isLoading = false;
  String? _errorMessage;
  int? _importedCount;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _processImport() async {
    if (_selectedBatchId == null) {
      setState(() => _errorMessage = 'Please select a destination batch.');
      return;
    }

    final rawText = _inputCtrl.text.trim();
    if (rawText.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste student rows.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final lines = rawText.split('\n');
    final rows = <StudentImportRow>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Expect format: Name, GuardianPhone, StudentPhone, Email
      final parts = trimmed.split(',').map((p) => p.trim()).toList();
      if (parts.isEmpty || parts[0].isEmpty) continue;

      final name = parts[0];
      final guardianPhone = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'N/A';
      final phone = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
      final email = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;

      rows.add(StudentImportRow(
        name: name,
        guardianPhone: guardianPhone,
        phone: phone,
        email: email,
      ));
    }

    if (rows.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No valid rows found to import.';
      });
      return;
    }

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(bulkImportStudentsUseCaseProvider);

    final result = await useCase(
      rawRows: rows,
      batchId: _selectedBatchId!,
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (count) {
        ref.read(studentListVersionProvider.notifier).state++;
        ref.invalidate(studentsListProvider);
        ref.invalidate(dashboardKpisProvider);
        setState(() {
          _isLoading = false;
          _importedCount = count;
        });
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bulk Student Import',
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
              if (_importedCount != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.paidBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Successfully imported $_importedCount student(s)!',
                    style: const TextStyle(color: AppColors.paid, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ] else ...[
                if (_errorMessage != null) ...[
                  ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 12),
                ],
                academicDataAsync.when(
                  data: (data) => DropdownButtonFormField<int>(
                    initialValue: _selectedBatchId,
                    decoration: const InputDecoration(labelText: 'Target Class & Section *'),
                    items: data.batches.map((b) {
                      final course = data.courses.where((c) => c.id == b.courseId).firstOrNull;
                      final label = course != null ? '${course.name} - ${b.name}' : b.name;
                      return DropdownMenuItem(value: b.id, child: Text(label));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBatchId = val),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load academic options'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paste rows in format: Name, GuardianPhone, StudentPhone, Email',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inputCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Ahmed Khan, 03001234567, 03211234567, ahmed@gmail.com\nFatima Ali, 03009876543',
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    PrimaryButton(
                      label: 'Import Students',
                      isLoading: _isLoading,
                      onPressed: _processImport,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
