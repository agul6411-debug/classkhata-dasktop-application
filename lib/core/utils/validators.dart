/// Input validation and sanitization utilities.
library;

/// Sanitizes a string to prevent formula injection when writing to Excel.
///
/// Cells beginning with `=`, `+`, `-`, `@` are formula injection vectors.
/// We prefix them with a single quote (Excel treats the cell as text).
String sanitizeExcelCell(String value) {
  const dangerous = ['=', '+', '-', '@'];
  if (value.isNotEmpty && dangerous.contains(value[0])) {
    return "'$value";
  }
  return value;
}

/// Validates an email address format (simple regex, offline only).
bool isValidEmail(String email) {
  return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(email);
}

/// Validates a Pakistani phone number (simple format).
bool isValidPhone(String phone) {
  final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^(\+92|0)?3\d{9}$').hasMatch(clean);
}

/// Clamps a string to a maximum length.
String truncate(String s, int max) =>
    s.length > max ? s.substring(0, max) : s;

/// Returns true if [value] is within [min]..[max] inclusive.
bool inRange(int value, int min, int max) => value >= min && value <= max;
