/// Dialog allowing school administration to customize Employment Terms, Rules & Code of Conduct.
/// These terms are automatically printed as Page 2 on every Staff Joining Dossier.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/services/staff_profile_service.dart';

class StaffTermsEditorDialog extends ConsumerStatefulWidget {
  const StaffTermsEditorDialog({super.key});

  @override
  ConsumerState<StaffTermsEditorDialog> createState() => _StaffTermsEditorDialogState();
}

class _StaffTermsEditorDialogState extends ConsumerState<StaffTermsEditorDialog> {
  final _termsCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final db = ref.read(appDatabaseProvider);
    final terms = await StaffProfileService.getSchoolTerms(db);
    if (mounted) {
      setState(() {
        _termsCtrl.text = terms;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTerms() async {
    setState(() => _isSaving = true);
    final db = ref.read(appDatabaseProvider);
    await StaffProfileService.saveSchoolTerms(db: db, terms: _termsCtrl.text);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('School Employment Terms & Rules saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _resetToDefault() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Default Rules?'),
        content: const Text(
          'Are you sure you want to revert to standard Pakistani school employment regulations? Your custom edits will be replaced.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _termsCtrl.text = StaffProfileService.defaultTerms;
        });
      }
    });
  }

  @override
  void dispose() {
    _termsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.gavel, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Employment Terms & Rules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.headingCol(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Employment Rules & Regulations • Printed on Page 2 of Joining Dossier',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),

              // Instructions banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customize your school\'s employment policies, probation terms, notice period, and code of conduct. These clauses print together with the Staff Form as an official 2-page binding agreement.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Editor Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TextField(
                        controller: _termsCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Enter school employment clauses, rules and conditions...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderCol(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderCol(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset to Standard Rules'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Save Terms & Rules',
                        icon: Icons.save,
                        isLoading: _isSaving,
                        onPressed: _saveTerms,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
