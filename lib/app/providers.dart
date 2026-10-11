/// Global Riverpod providers for core services.
///
/// All providers here are initialized once and shared across the app.
/// Features import from this file for database, security, and logger access.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/database/app_database.dart';
import '../core/security/password_hasher.dart';
import '../core/security/key_store.dart';
import '../core/logging/app_logger.dart';

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
