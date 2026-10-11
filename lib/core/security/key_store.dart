/// Secure storage for the database encryption key using the Windows
/// Credential Manager (via flutter_secure_storage).
///
/// The DB key is generated once at first run, stored securely, and
/// never written anywhere else (not logs, not disk, not config files).
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';

const _dbKeyStorageKey = 'classkhata_db_key';

/// Manages the SQLite database encryption key in the Windows Credential Store.
class KeyStore {
  KeyStore._();
  static final KeyStore instance = KeyStore._();

  final _storage = const FlutterSecureStorage();

  /// Returns the database encryption key, generating one if it doesn't exist.
  Future<Result<String>> getOrCreateDbKey() async {
    try {
      final existing = await _storage.read(key: _dbKeyStorageKey);
      if (existing != null && existing.isNotEmpty) {
        return Success(existing);
      }
      // Generate a 32-byte (256-bit) random key
      final key = _generateSecureKey(32);
      await _storage.write(key: _dbKeyStorageKey, value: key);
      await AppLogger.instance.info('DB encryption key created and stored securely');
      return Success(key);
    } catch (e, st) {
      await AppLogger.instance.critical('Failed to access secure key store', error: e, stack: st);
      return Failure(
        DatabaseFailure('Cannot access secure key store', technicalDetail: e.toString()),
      );
    }
  }

  /// Deletes the DB key from the credential store.
  /// WARNING: This will make the database permanently unreadable.
  Future<Result<void>> deleteDbKey() async {
    try {
      await _storage.delete(key: _dbKeyStorageKey);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('Failed to delete DB key', error: e, stack: st);
      return Failure(DatabaseFailure('Failed to delete DB key', technicalDetail: e.toString()));
    }
  }

  /// Generates a URL-safe base64-encoded random key of [byteLength] bytes.
  String _generateSecureKey(int byteLength) {
    final rng = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
