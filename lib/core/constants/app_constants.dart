/// Application-wide constants.
library;

class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------------
  // App identity
  // ---------------------------------------------------------------------------
  static const String appName = 'ClassKhata';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String orgName = 'pk.classkhata';

  // ---------------------------------------------------------------------------
  // Trial / Licensing
  // ---------------------------------------------------------------------------
  static const int trialDays = 7;

  // ---------------------------------------------------------------------------
  // Security
  // ---------------------------------------------------------------------------
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration autoLockDuration = Duration(minutes: 10);
  static const int minPasswordLength = 8;

  // ---------------------------------------------------------------------------
  // Database
  // ---------------------------------------------------------------------------
  static const int dbSchemaVersion = 1;
  static const String dbFileName = 'classkhata.db';
  static const String backupDirName = 'backups';

  // ---------------------------------------------------------------------------
  // Audit
  // ---------------------------------------------------------------------------
  static const String auditChainGenesisHash = 'GENESIS';

  // ---------------------------------------------------------------------------
  // Receipt
  // ---------------------------------------------------------------------------
  static const int receiptNumberPadding = 6; // e.g. RCP-000001

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------
  static const Duration autoBackupInterval = Duration(hours: 24);
  static const int maxAutoBackups = 30;
}
