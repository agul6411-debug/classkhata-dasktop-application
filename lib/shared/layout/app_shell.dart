/// Main app shell with slim left sidebar.
///
/// 6 nav items: Dashboard, Students, Fees, Payroll, Inventory, Reports.
/// Settings at the bottom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/backup/presentation/providers/backup_providers.dart';
import '../../features/fees/presentation/widgets/fee_collection_wizard.dart';
import '../../features/students/presentation/widgets/student_form_dialog.dart';

class _NewStudentIntent extends Intent {
  const _NewStudentIntent();
}

class _CollectFeeIntent extends Intent {
  const _CollectFeeIntent();
}

class _TriggerBackupIntent extends Intent {
  const _TriggerBackupIntent();
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(autoLockNotifierProvider);
    if (isLocked) {
      return const _LockScreen();
    }

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _NewStudentIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const _CollectFeeIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const _TriggerBackupIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewStudentIntent: CallbackAction<_NewStudentIntent>(
            onInvoke: (_) => showDialog<bool>(
              context: context,
              builder: (_) => const StudentFormDialog(),
            ),
          ),
          _CollectFeeIntent: CallbackAction<_CollectFeeIntent>(
            onInvoke: (_) => showDialog<bool>(
              context: context,
              builder: (_) => const FeeCollectionWizard(),
            ),
          ),
          _TriggerBackupIntent: CallbackAction<_TriggerBackupIntent>(
            onInvoke: (_) async {
              final user = ref.read(authSessionNotifierProvider);
              final repo = ref.read(backupRepositoryProvider);
              final res = await repo.createBackup(type: 'manual', createdBy: user?.id ?? 1);
              if (context.mounted) {
                res.fold(
                  onSuccess: (meta) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup created: ${meta.filePath}'), backgroundColor: Colors.teal),
                  ),
                  onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup failed: ${f.message}'), backgroundColor: Colors.red),
                  ),
                );
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                const _Sidebar(),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      width: 200,
      color: AppColors.surface,
      child: Column(
        children: [
          // App brand
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'ClassKhata',
              style: TextStyle(
                color: AppColors.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Main nav items
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/dashboard',
            isActive: location.startsWith('/dashboard'),
          ),
          _NavItem(
            icon: Icons.school_outlined,
            label: 'Students',
            route: '/students',
            isActive: location.startsWith('/students'),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Fees',
            route: '/fees',
            isActive: location.startsWith('/fees'),
          ),
          _NavItem(
            icon: Icons.people_outlined,
            label: 'Payroll',
            route: '/payroll',
            isActive: location.startsWith('/payroll'),
          ),
          _NavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            route: '/inventory',
            isActive: location.startsWith('/inventory'),
          ),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Reports',
            route: '/reports',
            isActive: location.startsWith('/reports'),
          ),

          const Spacer(),
          const Divider(height: 1),

          // Settings at the bottom
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            route: '/settings',
            isActive: location.startsWith('/settings'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
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
// Lock screen overlay
// ---------------------------------------------------------------------------

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = ref.read(authSessionNotifierProvider);
    if (user == null) {
      setState(() { _isLoading = false; _error = 'No active session.'; });
      return;
    }
    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(email: user.email, password: _passwordCtrl.text);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ref.read(autoLockNotifierProvider.notifier).unlock();
        _passwordCtrl.clear();
        setState(() => _isLoading = false);
      },
      onFailure: (f) => setState(() {
        _isLoading = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 40, color: AppColors.accent),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your password to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.overdueBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.overdue, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onFieldSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _unlock,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
