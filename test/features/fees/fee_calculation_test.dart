import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:classkhata/features/fees/domain/usecases/fee_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fee Calculations & Status Transitions', () {
    test('calculateTotalDue combines base fee, discount, late fee, and carry forward', () {
      final base = Money.fromRupees(5000); // 5,000 PKR
      final discount = Money.fromRupees(500); // 500 PKR discount
      final lateFee = Money.fromRupees(200); // 200 PKR late fee
      final carryForward = Money.fromRupees(1000); // 1,000 PKR unpaid from last month

      final total = FeeCalculator.calculateTotalDue(
        baseAmount: base,
        discount: discount,
        lateFee: lateFee,
        carryForward: carryForward,
      );

      // (5000 - 500) + 200 + 1000 = 5700
      expect(total.inRupees, 5700.0);
      expect(total.paisa, 570000);
    });

    test('calculateTotalDue clamps discount to zero if discount exceeds base', () {
      final base = Money.fromRupees(1000);
      final discount = Money.fromRupees(1500); // larger than base

      final total = FeeCalculator.calculateTotalDue(
        baseAmount: base,
        discount: discount,
        lateFee: const Money(0),
        carryForward: const Money(0),
      );

      expect(total.inRupees, 0.0);
    });

    test('determineStatus correctly identifies paid status', () {
      final total = Money.fromRupees(3000);
      final paid = Money.fromRupees(3000);
      final dueDate = DateTime.now().add(const Duration(days: 5));

      final status = FeeCalculator.determineStatus(
        totalDue: total,
        amountPaid: paid,
        dueDate: dueDate,
      );

      expect(status, VoucherStatus.paid);
    });

    test('determineStatus identifies partial and overdue statuses', () {
      final total = Money.fromRupees(3000);
      final paid = Money.fromRupees(1500);
      final futureDue = DateTime.now().add(const Duration(days: 5));
      final pastDue = DateTime.now().subtract(const Duration(days: 5));

      // Partial before due date
      expect(
        FeeCalculator.determineStatus(totalDue: total, amountPaid: paid, dueDate: futureDue),
        VoucherStatus.partial,
      );

      // Overdue after due date even if partially paid
      expect(
        FeeCalculator.determineStatus(totalDue: total, amountPaid: paid, dueDate: pastDue),
        VoucherStatus.overdue,
      );

      // Unpaid before due date
      expect(
        FeeCalculator.determineStatus(totalDue: total, amountPaid: const Money(0), dueDate: futureDue),
        VoucherStatus.unpaid,
      );

      // Overdue after due date if unpaid
      expect(
        FeeCalculator.determineStatus(totalDue: total, amountPaid: const Money(0), dueDate: pastDue),
        VoucherStatus.overdue,
      );
    });

    test('calculateCarryForward computes remaining balance accurately in paisa', () {
      final total = Money.fromRupees(4000);
      final paid = Money.fromRupees(2500);

      final carry = FeeCalculator.calculateCarryForward(totalDue: total, amountPaid: paid);
      expect(carry.inRupees, 1500.0);
      expect(carry.paisa, 150000);

      // Overpaid or fully paid produces zero carry-forward
      final overpaid = Money.fromRupees(4500);
      expect(FeeCalculator.calculateCarryForward(totalDue: total, amountPaid: overpaid).isZero, true);
    });
  });
}
