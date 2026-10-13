/// Main Drift database with SQLite3MultipleCiphers encryption.
///
/// The encryption key is retrieved from the Windows Credential Store
/// via [KeyStore] and passed to the database via the PRAGMA key.
/// All migrations are versioned and tested.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../logging/app_logger.dart';
import '../security/key_store.dart';
import 'tables/academic_tables.dart';
import 'tables/core_tables.dart';
import 'tables/fee_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/payroll_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UsersTable,
    RecoveryKeysTable,
    AcademyProfileTable,
    LicenseStateTable,
    AuditLogTable,
    SettingsTable,
    BackupsMetaTable,
    ApprovalRequestsTable,
    AcademicSessionsTable,
    CoursesTable,
    BatchesTable,
    FamiliesTable,
    StudentsTable,
    FeeStructuresTable,
    ReceiptCountersTable,
    FeeVouchersTable,
    ReceiptsTable,
    PaymentsTable,
    ExpenseCategoriesTable,
    ExpensesTable,
    CashBookEntriesTable,
    DayClosingsTable,
    StaffMembersTable,
    SalaryStructuresTable,
    PayrollRunsTable,
    StaffAdvancesTable,
    InventoryCategoriesTable,
    InventoryItemsTable,
    InventoryMovementsTable,
    StockTakesTable,
    SuppliersTable,
    SupplierLedgerTable,
    PurchasesTable,
    PurchaseItemsTable,
    ItemIssuancesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.e);

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  /// Opens the encrypted database. Must be called after [KeyStore] is ready.
  static Future<AppDatabase> open() async {
    final dbKey = await _getDbKey();
    final dbFile = await _dbFile();

    await AppLogger.instance.info('Opening database at ${dbFile.path}');

    final executor = NativeDatabase.createInBackground(
      dbFile,
      setup: (rawDb) {
        // Apply the encryption key via SQLite3MultipleCiphers PRAGMA.
        // This must be the first statement executed on the connection.
        rawDb.execute("PRAGMA key = '$dbKey';");
        // Use WAL mode for better concurrency and crash safety.
        rawDb.execute('PRAGMA journal_mode = WAL;');
        // Enforce foreign key constraints.
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );

    return AppDatabase._(executor);
  }

  @override
  int get schemaVersion => AppConstants.dbSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await AppLogger.instance.info('Creating database schema v$schemaVersion');
          await m.createAll();
          await _seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          await AppLogger.instance.info('Migrating database from v$from to v$to');
          // Future migrations go here as numbered blocks:
          // if (from < 2) { ... }
        },
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await AppLogger.instance.info('Database created fresh.');
          }
          // Run integrity check on every open
          await _runIntegrityCheck();
        },
      );

  /// Seeds initial settings and defaults on first run.
  Future<void> _seedDefaults() async {
    // Language default: English
    await into(settingsTable).insert(
      SettingsTableCompanion.insert(key: 'language', value: 'en'),
    );
    // Theme default: light
    await into(settingsTable).insert(
      SettingsTableCompanion.insert(key: 'theme', value: 'light'),
    );
    // Auto-lock: enabled
    await into(settingsTable).insert(
      SettingsTableCompanion.insert(key: 'auto_lock_enabled', value: 'true'),
    );
    // Auto-backup: enabled
    await into(settingsTable).insert(
      SettingsTableCompanion.insert(key: 'auto_backup_enabled', value: 'true'),
    );
  }

  Future<void> _runIntegrityCheck() async {
    try {
      final result = await customSelect('PRAGMA integrity_check;').get();
      final status = result.first.read<String>('integrity_check');
      if (status != 'ok') {
        await AppLogger.instance.critical('Database integrity check failed: $status');
      } else {
        await AppLogger.instance.info('Database integrity check: ok');
      }
    } catch (e, st) {
      await AppLogger.instance.critical('Integrity check error', error: e, stack: st);
    }
  }

  static Future<String> _getDbKey() async {
    final result = await KeyStore.instance.getOrCreateDbKey();
    return result.fold(
      onSuccess: (key) => key,
      onFailure: (f) => throw Exception('Cannot retrieve DB key: ${f.message}'),
    );
  }

  static Future<File> _dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, AppConstants.dbFileName));
  }
}
