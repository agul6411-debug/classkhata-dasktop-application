/// Day Closing modal dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/finance_providers.dart';

class DayClosingDialog extends ConsumerStatefulWidget {
  const DayClosingDialog({super.key});

  @override
  ConsumerState<DayClosingDialog> createState() => _DayClosingDialogState();
}

class _DayClosingDialogState extends ConsumerState<DayClosingDialog> {
  final _openingCtrl = TextEditingController(text: '0');
  final _actualCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _openingCtrl.dispose();
    _actualCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final openingRupees = double.tryParse(_openingCtrl.text.trim()) ?? 0;
    final actualRupees = double.tryParse(_actualCtrl.text.trim()) ?? 0;

    if (_actualCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter actual cash count in drawer.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final useCase = ref.read(dayClosingUseCaseProvider);

    final result = await useCase(
      date: DateTime.now(),
      openingCash: Money.fromRupees(openingRupees),
      actualCash: Money.fromRupees(actualRupees),
      discrepancyNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      closedBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (closing) {
        ref.invalidate(dayClosingsListProvider);
        Navigator.of(context).pop(closing);
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
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'End-of-Day Cash Closing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingCol(context)),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _openingCtrl,
                label: 'Opening Cash in Drawer (Rs.)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _actualCtrl,
                label: 'Actual Counted Cash in Hand (Rs.) *',
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _noteCtrl,
                label: 'Discrepancy Note (Optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  PrimaryButton(label: 'Execute Closing', isLoading: _isLoading, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
