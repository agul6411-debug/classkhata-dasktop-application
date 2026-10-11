/// Application entry point.
///
/// Initializes core services before the UI runs:
///   1. WidgetsFlutterBinding
///   2. AppLogger
///   3. PasswordHasher (loads native Argon2 library)
///   4. AppDatabase (opens encrypted SQLite file)
///   5. Checks first-run state → routes to /setup or /login
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/app_database.dart';
import 'core/logging/app_logger.dart';
import 'core/security/password_hasher.dart';
import 'app/app.dart';
import 'app/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Logger
  await AppLogger.instance.initialize();
  await AppLogger.instance.info('ClassKhata starting…');

  // 2. Argon2 native library
  await PasswordHasher.instance.initialize();

  // 3. Encrypted database
  final db = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the initialized database into the global provider
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const ClassKhataApp(),
    ),
  );
}
