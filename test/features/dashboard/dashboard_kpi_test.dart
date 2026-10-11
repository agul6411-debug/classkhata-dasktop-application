import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/dashboard/domain/entities/dashboard_kpis.dart';

void main() {
  group('Dashboard KPIs Calculation', () {
    test('Calculates collection percentage and aggregates metrics properly', () {
      final kpis = DashboardKpis(
        monthYear: '2026-10',
        expectedTotal: Money.fromRupees(100000), // 100,000 PKR
        collectedTotal: Money.fromRupees(75000),  // 75,000 PKR
        pendingTotal: Money.fromRupees(25000),    // 25,000 PKR
        overdueTotal: Money.fromRupees(10000),    // 10,000 PKR
        studentsCount: 50,
        coursesCount: 4,
        batchesCount: 6,
        paidCount: 30,
        partialCount: 10,
        unpaidCount: 8,
        overdueCount: 2,
        alerts: const [
          DashboardAlert(
            title: 'Fee Due',
            message: '5 vouchers are due in 2 days.',
          ),
        ],
      );

      expect(kpis.collectionPercentage, 75.0);
      expect(kpis.pendingTotal.inRupees, 25000.0);
      expect(kpis.studentsCount, 50);
      expect(kpis.alerts.length, 1);
    });

    test('Handles zero expected total without division by zero', () {
      final kpis = DashboardKpis(
        monthYear: '2026-10',
        expectedTotal: const Money(0),
        collectedTotal: const Money(0),
        pendingTotal: const Money(0),
        overdueTotal: const Money(0),
        studentsCount: 0,
        coursesCount: 0,
        batchesCount: 0,
        paidCount: 0,
        partialCount: 0,
        unpaidCount: 0,
        overdueCount: 0,
      );

      expect(kpis.collectionPercentage, 0.0);
    });
  });
}
