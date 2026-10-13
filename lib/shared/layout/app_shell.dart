/// Main app shell with slim left sidebar.
///
/// 6 nav items: Dashboard, Students, Fees, Payroll, Inventory, Reports.
/// Settings at the bottom.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/backup/presentation/providers/backup_providers.dart';
import '../../features/fees/presentation/widgets/fee_collection_wizard.dart';
import '../../features/licensing/presentation/widgets/license_banner.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../features/students/presentation/widgets/student_form_dialog.dart';
import '../widgets/global_search_dialog.dart';

class _NewStudentIntent extends Intent {
  const _NewStudentIntent();
}

class _CollectFeeIntent extends Intent {
  const _CollectFeeIntent();
}

class _TriggerBackupIntent extends Intent {
  const _TriggerBackupIntent();
}

class _GlobalSearchIntent extends Intent {
  const _GlobalSearchIntent();
}

class _HelpShortcutsIntent extends Intent {
  const _HelpShortcutsIntent();
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

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
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _GlobalSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.f1): const _HelpShortcutsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GlobalSearchIntent: CallbackAction<_GlobalSearchIntent>(
            onInvoke: (_) => showDialog<void>(
              context: context,
              builder: (_) => const GlobalSearchDialog(),
            ),
          ),
          _HelpShortcutsIntent: CallbackAction<_HelpShortcutsIntent>(
            onInvoke: (_) => _showShortcutsHelp(context),
          ),
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
                Expanded(
                  child: Column(
                    children: [
                      const LicenseBanner(),
                      _buildTopHeaderBar(context),
                      _buildIntegrityBanner(context, ref),
                      const Divider(height: 1),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final inputColor = isDark ? AppColors.darkBackground : AppColors.inputFill;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: surfaceColor,
      child: Row(
        children: [
          // Global Search Clickable Pill
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const GlobalSearchDialog(),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: textMutedColor),
                    const SizedBox(width: 8),
                    Text(
                      'Search students, staff, items, receipts... (Ctrl+K)',
                      style: TextStyle(fontSize: 12, color: textMutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Quick shortcut buttons
          Tooltip(
            message: 'New Student (Ctrl+N)',
            child: IconButton(
              icon: Icon(Icons.person_add_alt_1, size: 18, color: headingColor),
              onPressed: () => showDialog<bool>(context: context, builder: (_) => const StudentFormDialog()),
            ),
          ),
          Tooltip(
            message: 'Collect Fee (Ctrl+F)',
            child: IconButton(
              icon: const Icon(Icons.point_of_sale, size: 18, color: AppColors.accent),
              onPressed: () => showDialog<bool>(context: context, builder: (_) => const FeeCollectionWizard()),
            ),
          ),
          Tooltip(
            message: 'Shortcuts Help (F1)',
            child: IconButton(
              icon: Icon(Icons.help_outline, size: 18, color: textMutedColor),
              onPressed: () => _showShortcutsHelp(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityBanner(BuildContext context, WidgetRef ref) {
    final integrityAsync = ref.watch(startupIntegrityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return integrityAsync.when(
      data: (res) {
        if (res.isHealthy || res.userFriendlyMessage == null) {
          return const SizedBox.shrink();
        }
        final bgColor = isDark ? const Color(0xFF451A03) : Colors.amber.shade100;
        final textColor = isDark ? const Color(0xFFFDE68A) : Colors.brown.shade900;
        final iconColor = isDark ? const Color(0xFFFBBF24) : Colors.brown.shade800;
        final borderColor = isDark ? const Color(0xFFB45309) : Colors.amber.shade300;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res.userFriendlyMessage!,
                  style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showShortcutsHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppColors.accent),
            SizedBox(width: 8),
            Text('ClassKhata Keyboard Shortcuts'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShortcutItem(keys: 'Ctrl + K', action: 'Open Global Search Palette'),
            _ShortcutItem(keys: 'Ctrl + N', action: 'Register New Student'),
            _ShortcutItem(keys: 'Ctrl + F', action: 'Quick Fee Collection Wizard'),
            _ShortcutItem(keys: 'Ctrl + B', action: 'Trigger Instant Encrypted Backup'),
            _ShortcutItem(keys: 'F1', action: 'Show This Shortcuts Reference'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({required this.keys, required this.action});
  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(keys, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          Text(action, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final profileAsync = ref.watch(academyProfileProvider);
    final profile = profileAsync.valueOrNull;
    final logoPath = profile?.logoPath?.trim();
    final hasLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
    final academyName = (profile?.name.trim().isNotEmpty ?? false) ? profile!.name.trim() : 'ClassKhata';
    final tagline = (profile?.tagline?.trim().isNotEmpty ?? false) ? profile!.tagline!.trim() : 'School Operations';

    return Container(
      width: 200,
      color: surfaceColor,
      child: Column(
        children: [
          // App brand & School Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasLogo ? Colors.transparent : AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                    border: hasLogo ? Border.all(color: AppColors.accent.withValues(alpha: 0.3)) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasLogo
                      ? Image.file(
                          File(logoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.school, color: Colors.white, size: 20),
                        )
                      : const Icon(Icons.school, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        academyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textMutedColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
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
          Divider(height: 1, color: borderColor),

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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
  });
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppColors.accent.withValues(alpha: 0.25) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppColors.accent : unselectedColor,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.accent : unselectedColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
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
                  Text(
                    'Session Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingCol(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your password to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMutedCol(context), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450A0A) : AppColors.overdueBg,
                        border: Border.all(color: isDark ? const Color(0xFF991B1B) : AppColors.overdue.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_error!, style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : AppColors.overdue, fontSize: 13)),
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
