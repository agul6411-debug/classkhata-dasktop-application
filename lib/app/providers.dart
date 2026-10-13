/// Global Riverpod providers for core services.
///
/// All providers here are initialized once and shared across the app.
/// Features import from this file for database, security, and logger access.
library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/services/startup_integrity_service.dart';

part 'providers.g.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

/// Provides the initialized [AppDatabase] instance.
/// Initialized in main() before the app runs; passed via ProviderScope.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be initialized before use.');
});

// ---------------------------------------------------------------------------
// Locale / Theme state
// ---------------------------------------------------------------------------

/// Currently selected locale code ('en' or 'ur').
@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  @override
  String build() => 'en';

  void setLocale(String code) => state = code;
}

/// Currently selected theme ('light' or 'dark').
@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  String build() => 'light';

  void setTheme(String mode) => state = mode;
}

// ---------------------------------------------------------------------------
// Startup integrity check provider
// ---------------------------------------------------------------------------

final startupIntegrityProvider = FutureProvider<IntegrityCheckResult>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dir = await getApplicationSupportDirectory();
  final backupDir = Directory(p.join(dir.path, AppConstants.backupDirName));
  final service = StartupIntegrityService(db, backupDir);
  return service.runStartupChecks();
});
