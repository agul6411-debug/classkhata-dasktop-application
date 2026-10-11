/// Domain entity for Dashboard KPIs and performance metrics.
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class DashboardAlert extends Equatable {
  final String title;
  final String message;
  final String severity; // 'warning', 'info', 'critical'

  const DashboardAlert({
    required this.title,
    required this.message,
    this.severity = 'warning',
  });

  @override
  List<Object?> get props => [title, message, severity];
}

class DashboardKpis extends Equatable {
  final String monthYear;
  final Money expectedTotal;
  final Money collectedTotal;
  final Money pendingTotal;
  final Money overdueTotal;

  // Counts
  final int studentsCount;
  final int coursesCount;
  final int batchesCount;
  final int staffCount;

  // Voucher breakdown
  final int paidCount;
  final int partialCount;
  final int unpaidCount;
  final int overdueCount;

  // Actionable Alerts
  final List<DashboardAlert> alerts;

  const DashboardKpis({
    required this.monthYear,
    required this.expectedTotal,
    required this.collectedTotal,
    required this.pendingTotal,
    required this.overdueTotal,
    required this.studentsCount,
    required this.coursesCount,
    required this.batchesCount,
    this.staffCount = 0,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
    required this.overdueCount,
    this.alerts = const [],
  });

  double get collectionPercentage {
    if (expectedTotal.isZero) return 0.0;
    return (collectedTotal.paisa / expectedTotal.paisa) * 100;
  }

  @override
  List<Object?> get props => [
        monthYear,
        expectedTotal,
        collectedTotal,
        pendingTotal,
        overdueTotal,
        studentsCount,
        coursesCount,
        batchesCount,
        staffCount,
        paidCount,
        partialCount,
        unpaidCount,
        overdueCount,
        alerts,
      ];
}
