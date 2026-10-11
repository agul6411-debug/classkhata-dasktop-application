import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/finance/domain/entities/finance_entities.dart';

void main() {
  group('Profit & Loss Logic', () {
    test('Calculates positive net profit and margin correctly', () {
      final totalIncome = Money.fromRupees(100000); // 100,000 PKR
      final feeIncome = Money.fromRupees(95000);
      final totalExpenses = Money.fromRupees(40000); // 40,000 PKR
      final netProfit = totalIncome - totalExpenses; // 60,000 PKR
      final margin = (netProfit.paisa / totalIncome.paisa) * 100;

      final summary = ProfitAndLossSummary(
        period: 'October 2026',
        totalIncome: totalIncome,
        feeIncome: feeIncome,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        marginPercentage: margin,
      );

      expect(summary.netProfit.inRupees, 60000.0);
      expect(summary.marginPercentage, 60.0);
      expect(summary.isProfitable, true);
    });

    test('Calculates net loss when expenses exceed income', () {
      final totalIncome = Money.fromRupees(50000);
      final totalExpenses = Money.fromRupees(75000);
      final netProfit = totalIncome - totalExpenses; // -25,000 PKR
      final margin = (netProfit.paisa / totalIncome.paisa) * 100;

      final summary = ProfitAndLossSummary(
        period: 'September 2026',
        totalIncome: totalIncome,
        feeIncome: totalIncome,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        marginPercentage: margin,
      );

      expect(summary.netProfit.isNegative, true);
      expect(summary.isProfitable, false);
      expect(summary.marginPercentage, -50.0);
    });

    test('Handles zero income without division by zero error', () {
      final totalIncome = const Money(0);
      final totalExpenses = Money.fromRupees(15000);
      final netProfit = totalIncome - totalExpenses;
      final margin = totalIncome.isZero ? 0.0 : (netProfit.paisa / totalIncome.paisa) * 100;

      final summary = ProfitAndLossSummary(
        period: 'August 2026',
        totalIncome: totalIncome,
        feeIncome: const Money(0),
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        marginPercentage: margin,
      );

      expect(summary.marginPercentage, 0.0);
      expect(summary.netProfit.inRupees, -15000.0);
    });
  });
}
