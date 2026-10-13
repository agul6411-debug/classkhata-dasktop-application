import 'package:classkhata/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('zero value', () {
      const m = Money.zero();
      expect(m.paisa, 0);
      expect(m.isZero, true);
    });

    test('fromRupees truncates (no rounding)', () {
      final m = Money.fromRupees(10.5);
      expect(m.paisa, 1050);
      final m2 = Money.fromRupees(10.009);
      expect(m2.paisa, 1000); // truncates, not rounds
    });

    test('addition', () {
      final a = Money.fromRupees(100);
      final b = Money.fromRupees(50.5);
      expect((a + b).paisa, 15050);
    });

    test('subtraction', () {
      final a = Money.fromRupees(100);
      final b = Money.fromRupees(30);
      expect((a - b).paisa, 7000);
    });

    test('multiplication by integer', () {
      final m = Money.fromRupees(100);
      expect((m * 3).paisa, 30000);
    });

    test('integer division', () {
      const m = Money.fromPaisa(1000);
      expect((m ~/ 3).paisa, 333); // truncates
    });

    test('comparison operators', () {
      const a = Money.fromPaisa(500);
      const b = Money.fromPaisa(1000);
      expect(a < b, true);
      expect(b > a, true);
      expect(a <= a, true);
      expect(b >= b, true);
    });

    test('equality via Equatable', () {
      const a = Money(500);
      const b = Money(500);
      const c = Money(600);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('isNegative', () {
      const m = Money(-100);
      expect(m.isNegative, true);
      expect(m.abs().paisa, 100);
    });

    test('format Rs.', () {
      expect(Money.fromRupees(1234.5).format(), 'Rs. 1,234.50');
      expect(const Money.zero().format(), 'Rs. 0.00');
      expect(const Money(-500).format(), '-Rs. 5.00');
    });

    test('compareTo', () {
      const a = Money.fromPaisa(100);
      const b = Money.fromPaisa(200);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(a), 0);
    });

    test('no floating-point drift', () {
      // 0.1 + 0.2 != 0.3 in floating-point; with integer paisa it's exact
      const a = Money.fromPaisa(10);
      const b = Money.fromPaisa(20);
      expect((a + b).paisa, 30);
    });
  });
}
