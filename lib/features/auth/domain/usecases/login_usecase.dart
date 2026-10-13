/// Login use case with lockout enforcement.
///
/// Permission checks and security rules live here, not in the UI.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

/// Use case: authenticate a user with email + password.
///
/// Enforces lockout and surfaces plain-language errors.
class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<Result<AuthUser>> call({
    required String email,
    required String password,
  }) async {
    // Basic input validation
    if (email.trim().isEmpty) {
      return const Failure(ValidationFailure('Email is required.'));
    }
    if (password.isEmpty) {
      return const Failure(ValidationFailure('Password is required.'));
    }

    // Check lockout status first
    final lockoutResult = await _repository.getLockoutStatus(email.trim());
    if (lockoutResult.isFailure) return Failure(lockoutResult.fold(
      onSuccess: (_) => const UnexpectedFailure(''),
      onFailure: (f) => f,
    ));

    final lockout = lockoutResult.valueOrThrow;
    if (lockout.isLocked) {
      await AppLogger.instance.warning('Login attempt on locked account: $email');
      return Failure(
        AuthFailure(
          'Account is locked. Try again in ${lockout.minutesRemaining} minutes.',
        ),
      );
    }

    final result = await _repository.login(email: email.trim(), password: password);
    await result.fold(
      onSuccess: (user) async {
        await AppLogger.instance.info('User logged in: ${user.id}');
      },
      onFailure: (f) async {
        await AppLogger.instance.warning('Login failed for $email: ${f.message}');
      },
    );
    return result;
  }
}
