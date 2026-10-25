/// App router using go_router with auth and setup guards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/security/permission_service.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/recover_password_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/fees/presentation/pages/fees_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/setup/presentation/pages/setup_wizard_page.dart';
import '../../features/students/presentation/pages/students_page.dart';
import '../../shared/layout/app_shell.dart';

part 'app_router.g.dart';

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
      final isChangePasswordPage = state.matchedLocation == '/change-password';

      // Allow recovery page without auth
      if (isRecoverPage) return null;

      // Allow setup only if unauthenticated (once logged in, redirect away)
      if (isSetupPage) {
        if (loggedIn) return '/dashboard';
        return null;
      }

      // Redirect unauthenticated users to login
      if (!loggedIn && !isLoginPage) return '/login';

      // Redirect authenticated users away from login
      if (loggedIn && isLoginPage) {
        if (authSession.mustChangePassword) return '/change-password';
        return '/dashboard';
      }

      // If user is required to change password, force /change-password
      if (loggedIn && authSession.mustChangePassword && !isChangePasswordPage) {
        return '/change-password';
      }

      // If user is on /change-password, allow
      if (loggedIn && isChangePasswordPage) return null;

      // Role-Based Access Control (RBAC) Route Guards
      if (loggedIn) {
        final loc = state.matchedLocation;
        if (loc.startsWith('/settings')) {
          final isAllowed = authSession.role == AppRole.admin ||
              authSession.permissions.contains(Permission.settingsEdit);
          if (!isAllowed) return '/dashboard';
        }
        if (loc.startsWith('/payroll')) {
          if (!authSession.permissions.contains(Permission.payrollView)) {
            return '/dashboard';
          }
        }
        if (loc.startsWith('/inventory')) {
          if (!authSession.permissions.contains(Permission.inventoryView)) {
            return '/dashboard';
          }
        }
        if (loc.startsWith('/fees')) {
          if (!authSession.permissions.contains(Permission.feesView)) {
            return '/dashboard';
          }
        }
        if (loc.startsWith('/students')) {
          if (!authSession.permissions.contains(Permission.studentsView)) {
            return '/dashboard';
          }
        }
        if (loc.startsWith('/reports')) {
          if (!authSession.permissions.contains(Permission.reportsView)) {
            return '/dashboard';
          }
        }
      }

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
        builder: (_, __) => const RecoverPasswordPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordPage(),
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
