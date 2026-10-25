/// Defensive input sanitization and encoding utilities.
/// Protects against:
/// 1. CSV / Spreadsheet Formula Injection (CWE-1236)
/// 2. Path Traversal & Arbitrary File Overwrite (CWE-22)
/// 3. Sensitive Data Exposure in Logs (CWE-532)
/// 4. Control Character & Null Byte Injection
library;

import 'package:path/path.dart' as p;

class InputSanitizer {
  InputSanitizer._();

  /// Dangerous leading characters that trigger formula execution in Excel/Calc.
  static final RegExp _formulaPrefixPattern = RegExp(r'^[=+\-@\t\r\|%]');

  /// Characters unsafe in file names on Windows and POSIX.
  static final RegExp _unsafeFileNamePattern = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Patterns for masking credentials and PII in logs.
  static final RegExp _sensitiveKeywords = RegExp(
    r'(password|passwd|secret|token|apiKey|api_key|recoveryKey|cnic)[\s:=]+([^\s,;]+)',
    caseSensitive: false,
  );

  /// Sanitizes text for storage and CSV export to neutralize formula injection.
  /// If [input] begins with a formula trigger, prepends an apostrophe `'`.
  static String sanitizeForExport(String? input) {
    if (input == null || input.isEmpty) return '';
    final cleaned = input.replaceAll('\x00', '').trim();
    if (_formulaPrefixPattern.hasMatch(cleaned)) {
      return "'$cleaned";
    }
    return cleaned;
  }

  /// Sanitizes text input by stripping null bytes and limiting maximum length.
  static String sanitizeText(String? input, {int maxLength = 500}) {
    if (input == null || input.isEmpty) return '';
    final cleaned = input.replaceAll('\x00', '').trim();
    if (cleaned.length > maxLength) {
      return cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Sanitizes a file name to prevent directory traversal (`..`, absolute paths, illegal chars).
  static String sanitizeFileName(String? fileName, {String defaultName = 'file'}) {
    if (fileName == null || fileName.trim().isEmpty) return defaultName;
    // Extract only the base name (strip any leading path components)
    var base = p.basename(fileName.trim()).replaceAll('\x00', '');
    // Remove unsafe Windows/POSIX characters
    base = base.replaceAll(_unsafeFileNamePattern, '_');
    // Remove double dots to prevent traversal
    while (base.contains('..')) {
      base = base.replaceAll('..', '_');
    }
    base = base.trim();
    return base.isEmpty ? defaultName : base;
  }

  /// Masks sensitive parameters (passwords, tokens, keys) in debug or error strings.
  static String maskSensitiveData(String logMessage) {
    return logMessage.replaceAllMapped(_sensitiveKeywords, (match) {
      final key = match.group(1);
      return '$key=********';
    });
  }
}
