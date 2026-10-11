/// Abstract auth repository interface.
/// Implementation lives in the data layer.
library;

import '../../../../core/errors/failures.dart';
import '../entities/auth_entities.dart';

/// Defines the auth operations available to use cases.
abstract interface class AuthRepository {
  /// Attempts to log in with [email] and [password].
  /// Handles lockout tracking internally.
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  });

  /// Logs out the current user (clears session).
  Future<Result<void>> logout();

  /// Returns the current lockout status for [email].
  Future<Result<LockoutStatus>> getLockoutStatus(String email);

  /// Changes the password for [userId].
  Future<Result<void>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  });

  /// Verifies the one-time recovery key for [email].
  Future<Result<bool>> verifyRecoveryKey({
    required String email,
    required String recoveryKey,
  });

  /// Resets the password for [email] using the recovery key.
  Future<Result<void>> resetPasswordWithRecoveryKey({
    required String email,
    required String recoveryKey,
    required String newPassword,
  });
}
