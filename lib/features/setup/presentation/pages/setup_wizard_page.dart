/// First-run setup wizard — 3 steps.
///
/// Step 1: Academy profile (name, tagline, phone, address)
/// Step 2: Admin account (name, email, password)
/// Step 3: Recovery key (display once, user confirms they've saved it)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/setup_data.dart';
import '../providers/setup_providers.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _step = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _recoveryKey;

  // Step 1 controllers
  final _academyNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _step1Key = GlobalKey<FormState>();

  // Step 2 controllers
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  final _step2Key = GlobalKey<FormState>();

  @override
  void dispose() {
    _academyNameCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!(_step2Key.currentState?.validate() ?? false)) return;
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final data = SetupData(
      academyName: _academyNameCtrl.text.trim(),
      tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      adminEmail: _adminEmailCtrl.text.trim(),
      adminPassword: _passwordCtrl.text,
    );

    final result = await ref.read(runSetupUseCaseProvider).call(data);
    if (!mounted) return;

    result.fold(
      onSuccess: (key) {
        setState(() {
          _recoveryKey = key;
          _isLoading = false;
          _step = 2;
        });
      },
      onFailure: (f) => setState(() {
        _isLoading = false;
        _errorMessage = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildStep1(),
                    1 => _buildStep2(),
                    2 => _buildStep3(),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Academy profile ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader('Step 1 of 2', 'Academy Profile',
              'Tell us about your academy.'),
          const SizedBox(height: 24),
          AppTextField(
            controller: _academyNameCtrl,
            label: 'Academy Name *',
            autofocus: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Academy name is required.' : null,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _taglineCtrl,
            label: 'Tagline (optional)',
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _phoneCtrl,
            label: 'Phone Number (optional)',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _addressCtrl,
            label: 'Address (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Next',
            onPressed: () {
              if (_step1Key.currentState?.validate() ?? false) {
                setState(() { _step = 1; _errorMessage = null; });
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Step 2: Admin account ──────────────────────────────────────────────────

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader('Step 2 of 2', 'Admin Account',
              'Create your administrator login.'),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            ErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],

          AppTextField(
            controller: _adminNameCtrl,
            label: 'Your Name *',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _adminEmailCtrl,
            label: 'Email *',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required.';
              if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(v.trim())) {
                return 'Enter a valid email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordCtrl,
            label: 'Password *',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required.';
              if (v.length < AppConstants.minPasswordLength) {
                return 'Password must be at least ${AppConstants.minPasswordLength} characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _confirmPasswordCtrl,
            label: 'Confirm Password *',
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password.';
              if (v != _passwordCtrl.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Create Account',
                  onPressed: _isLoading ? null : _completeSetup,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Recovery key ───────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.key_outlined, size: 40, color: AppColors.accent),
        const SizedBox(height: 16),
        Text(
          'Save Your Recovery Key',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.headingCol(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This key is shown only once. If you forget your password, '
          'this key is the only way to recover access. Store it safely.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMutedCol(context), fontSize: 13),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.subCardBg(context),
            border: Border.all(color: AppColors.borderCol(context)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _recoveryKey ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: AppColors.headingCol(context),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _recoveryKey ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recovery key copied to clipboard.')),
            );
          },
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: "I've Saved It — Continue",
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _stepHeader(String step, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.headingCol(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: AppColors.textMutedCol(context), fontSize: 13)),
      ],
    );
  }
}
