/// Integer-based money value type.
///
/// All monetary values in ClassKhata are stored and manipulated as [int]
/// representing the smallest currency unit (paisa, where 1 rupee = 100 paisa).
/// This eliminates floating-point rounding errors entirely.
library;

import 'package:equatable/equatable.dart';

/// An immutable money value stored as integer paisa.
///
/// Never create this from a `double`. Use [Money.fromRupees] only for
/// user-facing input, and prefer [Money.fromPaisa] internally.
class Money extends Equatable implements Comparable<Money> {
  /// The value in paisa (smallest unit). Must be non-negative for most uses.
  final int paisa;

  const Money(this.paisa);

  /// Creates a zero-value Money.
  const Money.zero() : paisa = 0;

  /// Creates Money from rupees. Truncates (does NOT round) to whole paisa.
  /// Use only for converting user-entered amounts.
  factory Money.fromRupees(num rupees) {
    return Money((rupees * 100).truncate());
  }

  /// Creates Money from a paisa integer.
  const factory Money.fromPaisa(int paisa) = Money;

  // ---------------------------------------------------------------------------
  // Arithmetic
  // ---------------------------------------------------------------------------

  Money operator +(Money other) => Money(paisa + other.paisa);
  Money operator -(Money other) => Money(paisa - other.paisa);
  Money operator *(int factor) => Money(paisa * factor);

  /// Divides and truncates. Use only for splitting evenly (e.g. installments).
  Money operator ~/(int divisor) => Money(paisa ~/ divisor);

  bool operator <(Money other) => paisa < other.paisa;
  bool operator <=(Money other) => paisa <= other.paisa;
  bool operator >(Money other) => paisa > other.paisa;
  bool operator >=(Money other) => paisa >= other.paisa;

  Money abs() => Money(paisa.abs());
  bool get isZero => paisa == 0;
  bool get isNegative => paisa < 0;
  bool get isPositive => paisa > 0;

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Returns the value in rupees as a double (for display ONLY).
  double get inRupees => paisa / 100.0;

  /// Returns a formatted string like "Rs. 1,234.56".
  String format() {
    final rupees = paisa ~/ 100;
    final remainder = (paisa % 100).abs();
    final sign = paisa < 0 ? '-' : '';
    return '${sign}Rs. ${_formatWithCommas(rupees.abs())}.${remainder.toString().padLeft(2, '0')}';
  }

  String _formatWithCommas(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final mod = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - mod) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  List<Object?> get props => [paisa];

  @override
  String toString() => format();
}
