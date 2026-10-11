/// Domain entities for Finance, Cash Book, and P&L.
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class ExpenseCategory extends Equatable {
  final int id;
  final String name;
  final String? description;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}

class Expense extends Equatable {
  final int id;
  final int categoryId;
  final String categoryName;
  final Money amount;
  final String description;
  final String paymentMode;
  final String? referenceNumber;
  final DateTime expenseDate;

  const Expense({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.paymentMode,
    this.referenceNumber,
    required this.expenseDate,
  });

  @override
  List<Object?> get props => [
        id,
        categoryId,
        categoryName,
        amount,
        description,
        paymentMode,
        referenceNumber,
        expenseDate,
      ];
}

class CashBookEntry extends Equatable {
  final int id;
  final String entryType; // 'inflow' or 'outflow'
  final String category;
  final Money amount;
  final String description;
  final String paymentMode;
  final DateTime entryDate;

  const CashBookEntry({
    required this.id,
    required this.entryType,
    required this.category,
    required this.amount,
    required this.description,
    required this.paymentMode,
    required this.entryDate,
  });

  bool get isInflow => entryType.toLowerCase() == 'inflow';
  bool get isOutflow => entryType.toLowerCase() == 'outflow';

  @override
  List<Object?> get props => [id, entryType, category, amount, description, paymentMode, entryDate];
}

class DayClosing extends Equatable {
  final int id;
  final DateTime closingDate;
  final Money openingCash;
  final Money totalReceipts;
  final Money totalExpenses;
  final Money expectedClosingCash;
  final Money actualCash;
  final Money discrepancy;
  final String? discrepancyNote;
  final int closedBy;
  final DateTime closedAt;

  const DayClosing({
    required this.id,
    required this.closingDate,
    required this.openingCash,
    required this.totalReceipts,
    required this.totalExpenses,
    required this.expectedClosingCash,
    required this.actualCash,
    required this.discrepancy,
    this.discrepancyNote,
    required this.closedBy,
    required this.closedAt,
  });

  bool get hasDiscrepancy => !discrepancy.isZero;

  @override
  List<Object?> get props => [
        id,
        closingDate,
        openingCash,
        totalReceipts,
        totalExpenses,
        expectedClosingCash,
        actualCash,
        discrepancy,
        discrepancyNote,
        closedBy,
        closedAt,
      ];
}

class ProfitAndLossSummary extends Equatable {
  final String period; // e.g. "October 2026"
  final Money totalIncome;
  final Money feeIncome;
  final Money totalExpenses;
  final Money netProfit;
  final double marginPercentage;

  const ProfitAndLossSummary({
    required this.period,
    required this.totalIncome,
    required this.feeIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.marginPercentage,
  });

  bool get isProfitable => netProfit.isPositive;

  @override
  List<Object?> get props => [
        period,
        totalIncome,
        feeIncome,
        totalExpenses,
        netProfit,
        marginPercentage,
      ];
}
