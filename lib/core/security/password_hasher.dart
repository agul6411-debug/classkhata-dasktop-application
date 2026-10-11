/// Password hashing using Argon2id via serverpod_argon2.
///
/// Each password gets a unique random salt. The hash is stored as an
/// Argon2 encoded string (includes algorithm, parameters, salt, and hash).
/// Never store plain-text passwords or use MD5/SHA-1/plain SHA-256.
library;

import 'dart:isolate';
import 'package:serverpod_argon2/serverpod_argon2.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';

/// Service for hashing and verifying passwords using Argon2id.
class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();

  Argon2? _argon2;

  Future<void> initialize() async {
    _argon2 = await Argon2.load();
  }

  /// Hashes a [password] and returns the Argon2 encoded string.
  /// The encoded string contains the salt and all parameters — store it as-is.
  /// Runs on a separate isolate to avoid blocking the UI.
  Future<Result<String>> hashPassword(String password) async {
    try {
      final argon2 = _requireInitialized();
      final encoded = await Isolate.run(() => argon2.hash(password));
      return Success(encoded);
    } catch (e, st) {
      await AppLogger.instance.error('Password hashing failed', error: e, stack: st);
      return Failure(AuthFailure('Failed to hash password', technicalDetail: e.toString()));
    }
  }

  /// Verifies [password] against the stored Argon2 [encodedHash].
  Future<Result<bool>> verifyPassword(String password, String encodedHash) async {
    try {
      final argon2 = _requireInitialized();
      final ok = await Isolate.run(() => argon2.verify(password, encodedHash));
      return Success(ok);
    } catch (e, st) {
      await AppLogger.instance.error('Password verification failed', error: e, stack: st);
      return Failure(AuthFailure('Failed to verify password', technicalDetail: e.toString()));
    }
  }

  Argon2 _requireInitialized() {
    if (_argon2 == null) {
      throw StateError('PasswordHasher not initialized. Call initialize() first.');
    }
    return _argon2!;
  }
}
