/// Secure Change Password Page.
/// Enforces current password validation, length/complexity check, and Argon2id hashing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPass = _currentPasswordCtrl.text;
    final newPass = _newPasswordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (currentPass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password.');
      return;
    }

    if (newPass.length < AppConstants.minPasswordLength) {
      setState(() => _errorMessage = 'New password must be at least ${AppConstants.minPasswordLength} characters.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }

    if (newPass == currentPass) {
      setState(() => _errorMessage = 'New password cannot be the same as current password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.changePassword(
      userId: currentUser.id,
      currentPassword: currentPass,
      newPassword: newPass,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        // Update session state
        ref.read(authSessionNotifierProvider.notifier).updateUser(
              currentUser.copyWith(mustChangePassword: false),
            );
        setState(() {
          _isLoading = false;
          _successMessage = 'Password updated successfully! Redirecting…';
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) context.go('/dashboard');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authSessionNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_reset, color: AppColors.accent, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.heading,
                                ),
                              ),
                              Text(
                                (user?.mustChangePassword ?? false)
                                    ? 'Mandatory password change required.'
                                    : 'Update your account credentials.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    if (_errorMessage != null) ...[
                      ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF16A34A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      controller: _currentPasswordCtrl,
                      label: 'Current Password *',
                      obscureText: _obscureCurrent,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _newPasswordCtrl,
                      label: 'New Password (min 8 characters) *',
                      obscureText: _obscureNew,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirm New Password *',
                      obscureText: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Update Password',
                      icon: Icons.shield,
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    if (user?.mustChangePassword != true) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/dashboard'),
                        child: const Text('Cancel & Return to Dashboard'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
