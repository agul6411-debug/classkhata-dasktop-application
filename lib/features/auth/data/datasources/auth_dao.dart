/// Auth DAO — database operations for users and lockout.
///
/// Accesses tables directly through [AppDatabase] without @DriftAccessor,
/// eliminating DAO codegen overhead and keeping core/ free of feature imports.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class AuthDao {

  const AuthDao(this._db);
  final AppDatabase _db;

  /// Returns the user row matching [email], or null.
  Future<UsersTableData?> getUserByEmail(String email) =>
      (_db.select(_db.usersTable)..where((u) => u.email.equals(email))).getSingleOrNull();

  /// Returns the user row matching [id], or null.
  Future<UsersTableData?> getUserById(int id) =>
      (_db.select(_db.usersTable)..where((u) => u.id.equals(id))).getSingleOrNull();

  /// Atomically increments failed attempts and optionally locks the account.
  Future<void> recordFailedLogin({
    required int userId,
    required int newAttemptCount,
    DateTime? lockUntil,
  }) =>
      (_db.update(_db.usersTable)..where((u) => u.id.equals(userId))).write(
        UsersTableCompanion(
          failedLoginAttempts: Value(newAttemptCount),
          lockedUntil: Value(lockUntil),
        ),
      );

  /// Clears failed attempts and lockout on successful login.
  Future<void> recordSuccessfulLogin(int userId) =>
      (_db.update(_db.usersTable)..where((u) => u.id.equals(userId))).write(
        UsersTableCompanion(
          failedLoginAttempts: const Value(0),
          lockedUntil: const Value(null),
          lastLoginAt: Value(DateTime.now()),
        ),
      );

  /// Creates a new user.
  Future<int> createUser(UsersTableCompanion user) =>
      _db.into(_db.usersTable).insert(user);

  /// Updates user fields.
  Future<void> updateUser(int userId, UsersTableCompanion data) =>
      (_db.update(_db.usersTable)..where((u) => u.id.equals(userId))).write(data);

  /// Returns all active users.
  Future<List<UsersTableData>> getAllUsers() =>
      (_db.select(_db.usersTable)..where((u) => u.isActive.equals(true))).get();

  // Recovery key operations
  Future<void> saveRecoveryKey(RecoveryKeysTableCompanion companion) =>
      _db.into(_db.recoveryKeysTable).insert(companion);

  Future<RecoveryKeysTableData?> getActiveRecoveryKey(int userId) =>
      (_db.select(_db.recoveryKeysTable)
            ..where((r) => r.userId.equals(userId) & r.isUsed.equals(false)))
          .getSingleOrNull();

  Future<void> markRecoveryKeyUsed(int keyId) =>
      (_db.update(_db.recoveryKeysTable)..where((r) => r.id.equals(keyId))).write(
        RecoveryKeysTableCompanion(
          isUsed: const Value(true),
          usedAt: Value(DateTime.now()),
        ),
      );
}
