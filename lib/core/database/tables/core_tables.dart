/// All Drift table definitions for ClassKhata.
///
/// Rules:
///   - Money is stored as INTEGER (paisa). Column type: IntColumn.
///   - No hard deletes for financial records; use reversed_at / cancelled_at.
///   - All tables include created_at and created_by.
library;

import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Users & Roles
// ---------------------------------------------------------------------------

class UsersTable extends Table {
  @override
  String get tableName => 'users';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 1, max: 255)();
  TextColumn get passwordHash => text()();
  TextColumn get role => text()(); // admin | accountant | teacher | viewer
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get mustChangePassword => boolean().withDefault(const Constant(true))();
  IntColumn get failedLoginAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

class RecoveryKeysTable extends Table {
  @override
  String get tableName => 'recovery_keys';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(UsersTable, #id)();
  TextColumn get keyHash => text()(); // SHA-256 of the recovery key
  BoolColumn get isUsed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get usedAt => dateTime().nullable()();
}

// ---------------------------------------------------------------------------
// Academy profile
// ---------------------------------------------------------------------------

class AcademyProfileTable extends Table {
  @override
  String get tableName => 'academy_profile';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get tagline => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get logoPath => text().nullable()(); // path to logo file
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// License state
// ---------------------------------------------------------------------------

class LicenseStateTable extends Table {
  @override
  String get tableName => 'license_state';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get status => text()(); // trial | active | expired
  DateTimeColumn get trialStartedAt => dateTime().nullable()();
  DateTimeColumn get activatedAt => dateTime().nullable()();
  TextColumn get licenseKey => text().nullable()(); // signed license token
  TextColumn get machineId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// Audit log
// ---------------------------------------------------------------------------

class AuditLogTable extends Table {
  @override
  String get tableName => 'audit_log';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()(); // e.g. 'payment.created', 'user.login'
  TextColumn get entityType => text()(); // e.g. 'Payment', 'User'
  TextColumn get entityId => text().nullable()();
  IntColumn get userId => integer().references(UsersTable, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get details => text().nullable()(); // JSON blob, no PII
  TextColumn get previousHash => text()();
  TextColumn get entryHash => text()();
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Backups metadata
// ---------------------------------------------------------------------------

class BackupsMetaTable extends Table {
  @override
  String get tableName => 'backups_meta';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text()();
  TextColumn get type => text()(); // manual | auto | pre_migration
  IntColumn get sizeBytes => integer()();
  TextColumn get checksum => text()(); // SHA-256 of backup file
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Approval requests (maker-checker)
// ---------------------------------------------------------------------------

class ApprovalRequestsTable extends Table {
  @override
  String get tableName => 'approval_requests';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // discount | refund | waiver | cancellation
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  @ReferenceName('requestedApprovals')
  IntColumn get requestedBy => integer().references(UsersTable, #id)();
  DateTimeColumn get requestedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get reason => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // pending | approved | rejected
  @ReferenceName('reviewedApprovals')
  IntColumn get reviewedBy => integer().nullable().references(UsersTable, #id)();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  TextColumn get reviewerNote => text().nullable()();
  /// Serialized JSON of the payload the approver will authorize.
  TextColumn get payload => text()();
}
