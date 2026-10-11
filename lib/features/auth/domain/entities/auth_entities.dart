/// Auth domain entities — pure Dart, no Flutter, no Drift imports.
library;

import '../../../../core/security/permission_service.dart';

/// An authenticated user session.
class AuthUser {
  final int id;
  final String name;
  final String email;
  final AppRole role;
  final Set<Permission> permissions;
  final bool mustChangePassword;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.mustChangePassword,
  });

  AuthUser copyWith({
    int? id,
    String? name,
    String? email,
    AppRole? role,
    Set<Permission>? permissions,
    bool? mustChangePassword,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}

/// Possible states of a login attempt.
enum LoginResult {
  success,
  invalidCredentials,
  accountLocked,
  mustChangePassword,
  unexpectedError,
}

/// Lockout status for a user.
class LockoutStatus {
  final bool isLocked;
  final DateTime? lockedUntil;
  final int failedAttempts;

  const LockoutStatus({
    required this.isLocked,
    this.lockedUntil,
    required this.failedAttempts,
  });

  int get minutesRemaining {
    if (lockedUntil == null) return 0;
    final diff = lockedUntil!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inMinutes + 1;
  }
}
