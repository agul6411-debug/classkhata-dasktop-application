/// App router using go_router with auth and setup guards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/setup/presentation/pages/setup_wizard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/students/presentation/pages/students_page.dart';
import '../../features/fees/presentation/pages/fees_page.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/layout/app_shell.dart';

part 'app_router.g.dart';

// Placeholder pages for routes not yet built (Phase 2+)
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(
            '$title — coming soon',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
}

/// The app router provider.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authSession = ref.watch(authSessionNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authSession != null;
      final isLoginPage = state.matchedLocation == '/login';
      final isSetupPage = state.matchedLocation == '/setup';
      final isRecoverPage = state.matchedLocation == '/recover-password';

      // Allow setup and recover pages without auth
      if (isSetupPage || isRecoverPage) return null;

      // Redirect unauthenticated users to login
      if (!loggedIn && !isLoginPage) return '/login';

      // Redirect authenticated users away from login
      if (loggedIn && isLoginPage) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/setup',
        builder: (_, __) => const SetupWizardPage(),
      ),
      GoRoute(
        path: '/recover-password',
        builder: (_, __) => const _PlaceholderPage(title: 'Password Recovery'),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const _PlaceholderPage(title: 'Change Password'),
      ),

      // Shell routes (require auth — sidebar layout)
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: '/students',
            builder: (_, __) => const StudentsPage(),
          ),
          GoRoute(
            path: '/fees',
            builder: (_, __) => const FeesPage(),
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, __) => const PayrollPage(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ),
  );
}
