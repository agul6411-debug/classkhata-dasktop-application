/// Local crash/error logger.
///
/// Writes timestamped lines to a log file in the app support directory.
/// Never logs passwords, keys, or personal data.
library;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../security/input_sanitizer.dart';

enum LogLevel { debug, info, warning, error, critical }

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  File? _logFile;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      await logDir.create(recursive: true);
      _logFile = File('${logDir.path}/classkhata.log');
      _initialized = true;
      await info('AppLogger initialized');
    } catch (e) {
      // Can't log the logger failure — print to console only
      // ignore: avoid_print
      print('[AppLogger] Failed to initialize: $e');
    }
  }

  Future<void> debug(String message, {Object? error, StackTrace? stack}) =>
      _write(LogLevel.debug, message, error: error, stack: stack);

  Future<void> info(String message, {Object? error, StackTrace? stack}) =>
      _write(LogLevel.info, message, error: error, stack: stack);

  Future<void> warning(String message, {Object? error, StackTrace? stack}) =>
      _write(LogLevel.warning, message, error: error, stack: stack);

  Future<void> error(String message, {Object? error, StackTrace? stack}) =>
      _write(LogLevel.error, message, error: error, stack: stack);

  Future<void> critical(String message, {Object? error, StackTrace? stack}) =>
      _write(LogLevel.critical, message, error: error, stack: stack);

  Future<void> _write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(8);
    final safeMessage = InputSanitizer.maskSensitiveData(message);
    final safeError = error != null ? InputSanitizer.maskSensitiveData(error.toString()) : null;
    final lines = StringBuffer('[$timestamp] [$levelStr] $safeMessage');
    if (safeError != null) lines.write('\n  Error: $safeError');
    if (stack != null) lines.write('\n  Stack: $stack');
    final line = '${lines.toString()}\n';

    // ignore: avoid_print
    print(line.trim());

    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(line, mode: FileMode.append);
      } catch (_) {
        // Swallowing only the log-write failure to avoid infinite recursion
      }
    }
  }
}
