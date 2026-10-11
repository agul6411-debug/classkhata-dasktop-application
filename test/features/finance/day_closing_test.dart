import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/finance/domain/entities/finance_entities.dart';

void main() {
  group('Day Closing Balancing & Discrepancies', () {
    test('Calculates zero discrepancy when actual cash matches expected', () {
      final opening = Money.fromRupees(5000); // 5,000 PKR opening in drawer
      final receipts = Money.fromRupees(25000); // 25,000 PKR collected
      final expenses = Money.fromRupees(8000); // 8,000 PKR paid out
      final expected = opening + receipts - expenses; // 22,000 PKR expected
      final actual = Money.fromRupees(22000); // 22,000 PKR counted
      final discrepancy = actual - expected; // 0

      final closing = DayClosing(
        id: 1,
        closingDate: DateTime.now(),
        openingCash: opening,
        totalReceipts: receipts,
        totalExpenses: expenses,
        expectedClosingCash: expected,
        actualCash: actual,
        discrepancy: discrepancy,
        closedBy: 1,
        closedAt: DateTime.now(),
      );

      expect(closing.expectedClosingCash.inRupees, 22000.0);
      expect(closing.discrepancy.isZero, true);
      expect(closing.hasDiscrepancy, false);
    });

    test('Identifies cash shortage as negative discrepancy', () {
      final opening = Money.fromRupees(2000);
      final receipts = Money.fromRupees(10000);
      final expenses = Money.fromRupees(1000);
      final expected = opening + receipts - expenses; // 11,000 PKR expected
      final actual = Money.fromRupees(10500); // 10,500 PKR counted (500 short)
      final discrepancy = actual - expected; // -500 PKR

      final closing = DayClosing(
        id: 2,
        closingDate: DateTime.now(),
        openingCash: opening,
        totalReceipts: receipts,
        totalExpenses: expenses,
        expectedClosingCash: expected,
        actualCash: actual,
        discrepancy: discrepancy,
        discrepancyNote: 'Short by 500 PKR, investigating change drawer.',
        closedBy: 1,
        closedAt: DateTime.now(),
      );

      expect(closing.discrepancy.inRupees, -500.0);
      expect(closing.discrepancy.isNegative, true);
      expect(closing.hasDiscrepancy, true);
    });

    test('Identifies cash surplus as positive discrepancy', () {
      final opening = Money.fromRupees(1000);
      final receipts = Money.fromRupees(5000);
      final expenses = const Money(0);
      final expected = opening + receipts - expenses; // 6,000 PKR expected
      final actual = Money.fromRupees(6200); // 6,200 PKR counted (200 surplus)
      final discrepancy = actual - expected;

      final closing = DayClosing(
        id: 3,
        closingDate: DateTime.now(),
        openingCash: opening,
        totalReceipts: receipts,
        totalExpenses: expenses,
        expectedClosingCash: expected,
        actualCash: actual,
        discrepancy: discrepancy,
        closedBy: 1,
        closedAt: DateTime.now(),
      );

      expect(closing.discrepancy.inRupees, 200.0);
      expect(closing.discrepancy.isPositive, true);
      expect(closing.hasDiscrepancy, true);
    });
  });
}
