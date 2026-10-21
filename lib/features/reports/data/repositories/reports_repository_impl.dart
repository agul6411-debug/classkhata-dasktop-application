/// Reports repository implementation assembling multi-module datasets,
/// rendering PDF documents, and writing formula-sanitized Excel files.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/payment_modes.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/audit_chain.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  const ReportsRepositoryImpl(this._db);
  final AppDatabase _db;

  @override
  Future<Result<ReportData>> buildReport(ReportFilter filter) async {
    try {
      final now = DateTime.now();
      switch (filter.reportType) {
        case ReportType.feeCollectionSummary:
          return Success(await _buildFeeCollectionSummary(filter, now));
        case ReportType.defaultersAging:
          return Success(await _buildDefaultersAging(filter, now));
        case ReportType.expenseSummary:
          return Success(await _buildExpenseSummary(filter, now));
        case ReportType.cashBookStatement:
          return Success(await _buildCashBookStatement(filter, now));
        case ReportType.dayClosingSummary:
          return Success(await _buildDayClosingSummary(filter, now));
        case ReportType.profitLossSummary:
          return Success(await _buildProfitLossSummary(filter, now));
        case ReportType.payrollRegister:
          return Success(await _buildPayrollRegister(filter, now));
        case ReportType.inventoryValuation:
          return Success(await _buildInventoryValuation(filter, now));
        case ReportType.inventoryMovements:
          return Success(await _buildInventoryMovements(filter, now));
        case ReportType.supplierLedger:
          return Success(await _buildSupplierLedger(filter, now));
        case ReportType.studentEnrollment:
          return Success(await _buildStudentEnrollment(filter, now));
        case ReportType.batchWiseFees:
          return Success(await _buildBatchWiseFees(filter, now));
        case ReportType.courseWiseFees:
          return Success(await _buildCourseWiseFees(filter, now));
        case ReportType.auditLog:
          return Success(await _buildAuditLog(filter, now));
      }
    } catch (e, st) {
      await AppLogger.instance.error('buildReport error', error: e, stack: st);
      return Failure(DatabaseFailure('Failed to generate report: ${e.toString()}'));
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Fee Collection Summary
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildFeeCollectionSummary(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final receipts = await (_db.select(_db.receiptsTable)
          ..where((t) =>
              t.receiptDate.isBiggerOrEqualValue(start) &
              t.receiptDate.isSmallerOrEqualValue(end) &
              t.isCancelled.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.receiptDate)]))
        .get();

    final vouchers = await _db.select(_db.feeVouchersTable).get();
    final students = await _db.select(_db.studentsTable).get();
    final batches = await _db.select(_db.batchesTable).get();

    final voucherMap = {for (final v in vouchers) v.id: v};
    final studentMap = {for (final s in students) s.id: s};
    final batchMap = {for (final b in batches) b.id: b.name};

    final batchFilterId = filter.batchFilter != null && filter.batchFilter!.isNotEmpty
        ? int.tryParse(filter.batchFilter!)
        : null;

    int totalAmountPaisa = 0;
    final rows = <List<String>>[];

    for (final r in receipts) {
      final voucher = voucherMap[r.voucherId];
      if (filter.batchFilter != null && filter.batchFilter!.isNotEmpty) {
        if (voucher == null) continue;
        if (batchFilterId != null && voucher.batchId != batchFilterId) continue;
        if (batchFilterId == null && batchMap[voucher.batchId] != filter.batchFilter) continue;
      }

      totalAmountPaisa += r.amountPaisa;
      final student = voucher != null ? studentMap[voucher.studentId] : null;
      final batchName = voucher != null ? (batchMap[voucher.batchId] ?? '-') : '-';

      rows.add([
        r.receiptNumber,
        '${r.receiptDate.day}/${r.receiptDate.month}/${r.receiptDate.year}',
        student?.name ?? 'Student #${r.voucherId}',
        batchName,
        voucher?.voucherNumber ?? '-',
        Money.fromPaisa(r.amountPaisa).format(),
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Fee Collection Summary',
      subtitle: 'From ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const ['Receipt #', 'Date', 'Student Name', 'Batch', 'Voucher #', 'Amount Collected'],
      rows: rows,
      summaryMetrics: {
        'Total Collected': Money.fromPaisa(totalAmountPaisa).format(),
        'Total Receipts': '${rows.length}',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Defaulters Aging Report (30 / 60 / 90 Days)
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildDefaultersAging(ReportFilter filter, DateTime now) async {
    final unpaidVouchers = await (_db.select(_db.feeVouchersTable)
          ..where((t) => t.status.equals('unpaid') | t.status.equals('partial'))
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .get();

    final students = await _db.select(_db.studentsTable).get();
    final batches = await _db.select(_db.batchesTable).get();
    final studentMap = {for (final s in students) s.id: s};
    final batchMap = {for (final b in batches) b.id: b.name};

    final batchFilterId = filter.batchFilter != null && filter.batchFilter!.isNotEmpty
        ? int.tryParse(filter.batchFilter!)
        : null;

    int totalOutstandingPaisa = 0;
    int count30 = 0;
    int count60 = 0;
    int count90 = 0;
    final rows = <List<String>>[];

    for (final v in unpaidVouchers) {
      if (filter.batchFilter != null && filter.batchFilter!.isNotEmpty) {
        if (batchFilterId != null && v.batchId != batchFilterId) continue;
        if (batchFilterId == null && batchMap[v.batchId] != filter.batchFilter) continue;
      }

      final student = studentMap[v.studentId];
      final batchName = batchMap[v.batchId] ?? '-';
      final remainingPaisa = v.totalDuePaisa - v.amountPaidPaisa;
      if (remainingPaisa <= 0) continue;

      totalOutstandingPaisa += remainingPaisa;

      final overdueDays = now.difference(v.dueDate).inDays;
      String bucket;
      if (overdueDays <= 30) {
        bucket = '0 - 30 Days';
        count30++;
      } else if (overdueDays <= 60) {
        bucket = '31 - 60 Days';
        count60++;
      } else if (overdueDays <= 90) {
        bucket = '61 - 90 Days';
        count90++;
      } else {
        bucket = '90+ Days';
        count90++;
      }

      rows.add([
        student?.name ?? 'Unknown',
        student?.guardianPhone ?? '-',
        batchName,
        v.voucherNumber,
        '${v.dueDate.day}/${v.dueDate.month}/${v.dueDate.year}',
        overdueDays > 0 ? '$overdueDays days' : 'Due today',
        bucket,
        Money.fromPaisa(remainingPaisa).format(),
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Defaulters Aging Report',
      subtitle: 'Outstanding fee aging breakdown as of ${now.day}/${now.month}/${now.year}',
      headers: const [
        'Student Name',
        'Guardian Phone',
        'Batch',
        'Voucher #',
        'Due Date',
        'Overdue',
        'Aging Bracket',
        'Amount Due',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Outstanding': Money.fromPaisa(totalOutstandingPaisa).format(),
        'Defaulters Count': '${rows.length}',
        '0 - 30 Days': '$count30',
        '31 - 60 Days': '$count60',
        '61+ Days': '$count90',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 2b. Operational Expenses Summary
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildExpenseSummary(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final expenses = await (_db.select(_db.expensesTable)
          ..where((t) =>
              t.expenseDate.isBiggerOrEqualValue(start) &
              t.expenseDate.isSmallerOrEqualValue(end) &
              t.reversedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();

    final categories = await _db.select(_db.expenseCategoriesTable).get();
    final catMap = {for (final c in categories) c.id: c.name};

    int totalAmountPaisa = 0;
    final rows = <List<String>>[];

    for (final exp in expenses) {
      totalAmountPaisa += exp.amountPaisa;
      final catName = catMap[exp.categoryId] ?? 'General';
      rows.add([
        '${exp.expenseDate.day}/${exp.expenseDate.month}/${exp.expenseDate.year}',
        catName,
        exp.description,
        PaymentModes.getPdfDisplayName(exp.paymentMode),
        exp.referenceNumber ?? '-',
        Money.fromPaisa(exp.amountPaisa).format(),
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Operational Expenses Summary',
      subtitle: 'From ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const ['Date', 'Category', 'Description', 'Payment Mode', 'Reference #', 'Amount (Rs.)'],
      rows: rows,
      summaryMetrics: {
        'Total Expenses': Money.fromPaisa(totalAmountPaisa).format(),
        'Total Entries': '${rows.length}',
        'Active Categories': '${catMap.length}',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Cash Book Statement
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildCashBookStatement(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final entries = await (_db.select(_db.cashBookEntriesTable)
          ..where((t) =>
              t.entryDate.isBiggerOrEqualValue(start) &
              t.entryDate.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.entryDate)]))
        .get();

    int totalInflowPaisa = 0;
    int totalOutflowPaisa = 0;
    final rows = <List<String>>[];

    for (final e in entries) {
      final isInflow = e.entryType.toLowerCase() == 'inflow';
      if (isInflow) {
        totalInflowPaisa += e.amountPaisa;
      } else {
        totalOutflowPaisa += e.amountPaisa;
      }

      rows.add([
        '${e.entryDate.day}/${e.entryDate.month}/${e.entryDate.year}',
        e.entryType.toUpperCase(),
        e.category.toUpperCase(),
        e.description,
        PaymentModes.getPdfDisplayName(e.paymentMode),
        isInflow ? Money.fromPaisa(e.amountPaisa).format() : '-',
        !isInflow ? Money.fromPaisa(e.amountPaisa).format() : '-',
      ]);
    }

    final netMovementPaisa = totalInflowPaisa - totalOutflowPaisa;

    return ReportData(
      type: filter.reportType,
      title: 'Cash Book Statement',
      subtitle: 'From ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const ['Date', 'Type', 'Category', 'Description', 'Mode', 'Inflow', 'Outflow'],
      rows: rows,
      summaryMetrics: {
        'Total Inflows': Money.fromPaisa(totalInflowPaisa).format(),
        'Total Outflows': Money.fromPaisa(totalOutflowPaisa).format(),
        'Net Movement': Money.fromPaisa(netMovementPaisa).format(),
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 3b. Day Closing & Cash Reconciliation
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildDayClosingSummary(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final closings = await (_db.select(_db.dayClosingsTable)
          ..where((t) =>
              t.closingDate.isBiggerOrEqualValue(start) &
              t.closingDate.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.closingDate)]))
        .get();

    final users = await _db.select(_db.usersTable).get();
    final userMap = {for (final u in users) u.id: u.name};

    int totalReceiptsPaisa = 0;
    int totalExpensesPaisa = 0;
    int totalDiscrepancyPaisa = 0;
    final rows = <List<String>>[];

    for (final c in closings) {
      totalReceiptsPaisa += c.totalReceiptsPaisa;
      totalExpensesPaisa += c.totalExpensesPaisa;
      totalDiscrepancyPaisa += c.discrepancyPaisa;

      rows.add([
        '${c.closingDate.day}/${c.closingDate.month}/${c.closingDate.year}',
        userMap[c.closedBy] ?? 'User #${c.closedBy}',
        Money.fromPaisa(c.openingCashPaisa).format(),
        Money.fromPaisa(c.totalReceiptsPaisa).format(),
        Money.fromPaisa(c.totalExpensesPaisa).format(),
        Money.fromPaisa(c.expectedClosingCashPaisa).format(),
        Money.fromPaisa(c.actualCashPaisa).format(),
        c.discrepancyPaisa == 0 ? 'MATCH (0)' : Money.fromPaisa(c.discrepancyPaisa).format(),
        c.discrepancyNote ?? '-',
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Day Closing & Drawer Reconciliation',
      subtitle: 'From ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const [
        'Closing Date',
        'Closed By',
        'Opening Cash',
        'Receipts',
        'Expenses',
        'Expected Cash',
        'Actual Cash',
        'Discrepancy',
        'Notes',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Receipts': Money.fromPaisa(totalReceiptsPaisa).format(),
        'Total Expenses': Money.fromPaisa(totalExpensesPaisa).format(),
        'Net Discrepancy': Money.fromPaisa(totalDiscrepancyPaisa).format(),
        'Total Closings': '${rows.length}',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Profit & Loss Summary
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildProfitLossSummary(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final receipts = await (_db.select(_db.receiptsTable)
          ..where((t) =>
              t.receiptDate.isBiggerOrEqualValue(start) &
              t.receiptDate.isSmallerOrEqualValue(end) &
              t.isCancelled.equals(false)))
        .get();

    final outflows = await (_db.select(_db.cashBookEntriesTable)
          ..where((t) =>
              t.entryType.equals('outflow') &
              t.entryDate.isBiggerOrEqualValue(start) &
              t.entryDate.isSmallerOrEqualValue(end)))
        .get();

    int totalIncomePaisa = 0;
    for (final r in receipts) {
      totalIncomePaisa += r.amountPaisa;
    }

    // Group expenses by category
    final expenseCatTotals = <String, int>{};
    int totalExpensePaisa = 0;

    for (final o in outflows) {
      totalExpensePaisa += o.amountPaisa;
      expenseCatTotals[o.category] = (expenseCatTotals[o.category] ?? 0) + o.amountPaisa;
    }

    final rows = <List<String>>[];
    rows.add(['Fee Revenue (Student Fees)', 'Income', '${receipts.length}', Money.fromPaisa(totalIncomePaisa).format()]);

    expenseCatTotals.forEach((cat, amount) {
      rows.add(['Expense: ${cat.toUpperCase()}', 'Expense', '-', Money.fromPaisa(amount).format()]);
    });

    final netProfitPaisa = totalIncomePaisa - totalExpensePaisa;
    final margin = totalIncomePaisa > 0 ? ((netProfitPaisa / totalIncomePaisa) * 100).toStringAsFixed(1) : '0.0';

    return ReportData(
      type: filter.reportType,
      title: 'Profit & Loss Statement',
      subtitle: 'Period: ${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}',
      headers: const ['Account / Category', 'Type', 'Entries Count', 'Total (Rs.)'],
      rows: rows,
      summaryMetrics: {
        'Gross Revenue': Money.fromPaisa(totalIncomePaisa).format(),
        'Total Expenses': Money.fromPaisa(totalExpensePaisa).format(),
        'Net Profit': Money.fromPaisa(netProfitPaisa).format(),
        'Profit Margin': '$margin%',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Monthly Payroll Register
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildPayrollRegister(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final startMonth = '${start.year}-${start.month.toString().padLeft(2, '0')}';
    final endMonth = '${end.year}-${end.month.toString().padLeft(2, '0')}';

    final query = _db.select(_db.payrollRunsTable);
    if (filter.monthYear != null && filter.monthYear!.isNotEmpty) {
      query.where((t) => t.monthYear.equals(filter.monthYear!));
    } else {
      query.where((t) => t.monthYear.isBiggerOrEqualValue(startMonth) & t.monthYear.isSmallerOrEqualValue(endMonth));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.monthYear), (t) => OrderingTerm.desc(t.createdAt)]);
    final runs = await query.get();

    final staff = await _db.select(_db.staffMembersTable).get();
    final staffMap = {for (final s in staff) s.id: s};

    int totalNetSalaryPaisa = 0;
    int paidCount = 0;
    int unpaidCount = 0;
    final rows = <List<String>>[];

    for (final r in runs) {
      final s = staffMap[r.staffId];
      totalNetSalaryPaisa += r.netSalaryPaisa;
      if (r.status.toLowerCase() == 'paid') {
        paidCount++;
      } else {
        unpaidCount++;
      }

      rows.add([
        s?.staffCode ?? '-',
        s?.name ?? 'Staff #${r.staffId}',
        s?.designation ?? '-',
        r.monthYear,
        Money.fromPaisa(r.baseSalaryPaisa).format(),
        Money.fromPaisa(r.allowancesPaisa).format(),
        Money.fromPaisa(r.deductionsPaisa).format(),
        Money.fromPaisa(r.advanceRecoveryPaisa).format(),
        Money.fromPaisa(r.netSalaryPaisa).format(),
        r.status.toUpperCase(),
        r.paidAt != null ? '${r.paidAt!.day}/${r.paidAt!.month}/${r.paidAt!.year}' : '-',
        r.paymentMode != null ? r.paymentMode!.toUpperCase() : '-',
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Monthly Payroll Register',
      subtitle: filter.monthYear != null
          ? 'Payroll for period ${filter.monthYear}'
          : 'Payroll records from $startMonth to $endMonth',
      headers: const [
        'Staff Code',
        'Staff Name',
        'Designation',
        'Period',
        'Base Pay',
        'Allowances',
        'Deductions',
        'Adv. Recovery',
        'Net Salary',
        'Status',
        'Paid Date',
        'Mode',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Net Payable': Money.fromPaisa(totalNetSalaryPaisa).format(),
        'Total Staff Runs': '${rows.length}',
        'Paid Runs': '$paidCount',
        'Unpaid Runs': '$unpaidCount',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Inventory Valuation
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildInventoryValuation(ReportFilter filter, DateTime now) async {
    final items = await (_db.select(_db.inventoryItemsTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    final categories = await _db.select(_db.inventoryCategoriesTable).get();
    final catMap = {for (final c in categories) c.id: c.name};

    int totalValuationPaisa = 0;
    int lowStockCount = 0;
    final rows = <List<String>>[];

    for (final i in items) {
      final valPaisa = i.unitCostPaisa * i.quantityOnHand;
      totalValuationPaisa += valPaisa;
      final isLow = i.quantityOnHand <= i.reorderLevel;
      if (isLow) lowStockCount++;

      rows.add([
        i.name,
        catMap[i.categoryId] ?? 'General',
        i.unit,
        '${i.quantityOnHand}',
        Money.fromPaisa(i.unitCostPaisa).format(),
        Money.fromPaisa(valPaisa).format(),
        '${i.reorderLevel}',
        isLow ? 'LOW STOCK' : 'OK',
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Inventory Stock & Asset Valuation',
      subtitle: 'Inventory position as of ${now.day}/${now.month}/${now.year}',
      headers: const [
        'Item Name',
        'Category',
        'Unit',
        'On Hand',
        'Unit Cost',
        'Total Valuation',
        'Reorder Level',
        'Stock Alert',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Asset Value': Money.fromPaisa(totalValuationPaisa).format(),
        'Total Unique Items': '${items.length}',
        'Low Stock Items': '$lowStockCount',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Inventory Movements History
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildInventoryMovements(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final movements = await (_db.select(_db.inventoryMovementsTable)
          ..where((t) =>
              t.movementDate.isBiggerOrEqualValue(start) &
              t.movementDate.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.movementDate)]))
        .get();

    final items = await _db.select(_db.inventoryItemsTable).get();
    final itemMap = {for (final i in items) i.id: i.name};

    int totalIn = 0;
    int totalOut = 0;
    final rows = <List<String>>[];

    for (final m in movements) {
      if (m.movementType == 'in') {
        totalIn += m.quantity;
      } else if (m.movementType == 'out') {
        totalOut += m.quantity;
      }

      rows.add([
        '${m.movementDate.day}/${m.movementDate.month}/${m.movementDate.year}',
        itemMap[m.itemId] ?? 'Item #${m.itemId}',
        m.movementType.toUpperCase(),
        '${m.quantity}',
        Money.fromPaisa(m.unitCostPaisa).format(),
        m.reason,
        m.referenceNumber ?? '-',
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Inventory Movement History',
      subtitle: 'Stock flow from ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const [
        'Date',
        'Item Name',
        'Movement Type',
        'Quantity',
        'Unit Cost',
        'Reason / Notes',
        'Reference #',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Received (In)': '$totalIn units',
        'Total Issued (Out)': '$totalOut units',
        'Total Movements': '${movements.length}',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Supplier Ledger & Payables
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildSupplierLedger(ReportFilter filter, DateTime now) async {
    final start = DateTime(filter.startDate.year, filter.startDate.month, filter.startDate.day);
    final end = DateTime(filter.endDate.year, filter.endDate.month, filter.endDate.day, 23, 59, 59);

    final ledgerRows = await (_db.select(_db.supplierLedgerTable)
          ..where((t) =>
              t.transactionDate.isBiggerOrEqualValue(start) &
              t.transactionDate.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();

    final suppliers = await _db.select(_db.suppliersTable).get();
    final supMap = {for (final s in suppliers) s.id: s.name};

    int totalPurchasesPaisa = 0;
    int totalPaymentsPaisa = 0;
    final rows = <List<String>>[];

    for (final l in ledgerRows) {
      if (l.transactionType == 'purchase') {
        totalPurchasesPaisa += l.amountPaisa;
      } else if (l.transactionType == 'payment') {
        totalPaymentsPaisa += l.amountPaisa;
      }

      rows.add([
        '${l.transactionDate.day}/${l.transactionDate.month}/${l.transactionDate.year}',
        supMap[l.supplierId] ?? 'Supplier #${l.supplierId}',
        l.transactionType.toUpperCase(),
        Money.fromPaisa(l.amountPaisa).format(),
        l.referenceNumber ?? '-',
        l.notes ?? '-',
      ]);
    }

    int totalOutstandingBalancePaisa = 0;
    for (final s in suppliers) {
      totalOutstandingBalancePaisa += s.currentBalancePaisa;
    }

    return ReportData(
      type: filter.reportType,
      title: 'Supplier Ledger & Payables Report',
      subtitle: 'Supplier ledger transactions from ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}',
      headers: const [
        'Date',
        'Supplier Name',
        'Transaction',
        'Amount',
        'Reference #',
        'Notes',
      ],
      rows: rows,
      summaryMetrics: {
        'Total Purchases': Money.fromPaisa(totalPurchasesPaisa).format(),
        'Total Payments Made': Money.fromPaisa(totalPaymentsPaisa).format(),
        'Outstanding Payables': Money.fromPaisa(totalOutstandingBalancePaisa).format(),
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 9. Student Enrollment Directory
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildStudentEnrollment(ReportFilter filter, DateTime now) async {
    final students = await (_db.select(_db.studentsTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    final batches = await _db.select(_db.batchesTable).get();
    final courses = await _db.select(_db.coursesTable).get();

    final batchMap = {for (final b in batches) b.id: b};
    final courseMap = {for (final c in courses) c.id: c.name};

    int activeCount = 0;
    final rows = <List<String>>[];

    for (final s in students) {
      final b = batchMap[s.batchId];
      final courseName = b != null ? (courseMap[b.courseId] ?? '-') : '-';
      if (s.status == 'active') activeCount++;

      rows.add([
        'STD-${s.id.toString().padLeft(4, '0')}',
        s.name,
        s.guardianPhone,
        courseName,
        b?.name ?? '-',
        '${s.joiningDate.day}/${s.joiningDate.month}/${s.joiningDate.year}',
        s.status.toUpperCase(),
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Student Enrollment & Strength',
      subtitle: 'Student registry as of ${now.day}/${now.month}/${now.year}',
      headers: const ['Admission #', 'Student Name', 'Guardian Phone', 'Course', 'Batch', 'Joined', 'Status'],
      rows: rows,
      summaryMetrics: {
        'Total Enrolled': '${students.length}',
        'Active Students': '$activeCount',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 10. Batch-wise Fee Summary
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildBatchWiseFees(ReportFilter filter, DateTime now) async {
    final batches = await _db.select(_db.batchesTable).get();
    final courses = await _db.select(_db.coursesTable).get();
    final courseMap = {for (final c in courses) c.id: c.name};

    final rows = <List<String>>[];
    var grossInvoicedPaisa = 0;
    var grossCollectedPaisa = 0;

    for (final b in batches) {
      final vouchers = await (_db.select(_db.feeVouchersTable)..where((v) => v.batchId.equals(b.id))).get();
      final batchInvoiced = vouchers.fold(0, (sum, v) => sum + v.totalDuePaisa);
      final batchCollected = vouchers.fold(0, (sum, v) => sum + v.amountPaidPaisa);
      final batchPending = batchInvoiced - batchCollected;
      grossInvoicedPaisa += batchInvoiced;
      grossCollectedPaisa += batchCollected;

      final rate = batchInvoiced > 0 ? ((batchCollected / batchInvoiced) * 100).toStringAsFixed(1) : '100.0';

      rows.add([
        b.name,
        courseMap[b.courseId] ?? 'Unknown',
        '${vouchers.length}',
        Money.fromPaisa(batchInvoiced).format(),
        Money.fromPaisa(batchCollected).format(),
        Money.fromPaisa(batchPending).format(),
        '$rate%',
      ]);
    }

    final grossPendingPaisa = grossInvoicedPaisa - grossCollectedPaisa;
    final overallRate = grossInvoicedPaisa > 0 ? ((grossCollectedPaisa / grossInvoicedPaisa) * 100).toStringAsFixed(1) : '100.0';

    return ReportData(
      type: filter.reportType,
      title: 'Batch-wise Fee Summary',
      subtitle: 'Invoiced, collected, and outstanding fee breakdown per batch',
      headers: const ['Batch Name', 'Course', 'Vouchers', 'Invoiced', 'Collected', 'Pending', 'Recovery %'],
      rows: rows,
      summaryMetrics: {
        'Total Invoiced': Money.fromPaisa(grossInvoicedPaisa).format(),
        'Total Collected': Money.fromPaisa(grossCollectedPaisa).format(),
        'Total Pending': Money.fromPaisa(grossPendingPaisa).format(),
        'Overall Recovery': '$overallRate%',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 11. Course-wise Fee Summary
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildCourseWiseFees(ReportFilter filter, DateTime now) async {
    final courses = await _db.select(_db.coursesTable).get();
    final batches = await _db.select(_db.batchesTable).get();

    final rows = <List<String>>[];
    var grossInvoicedPaisa = 0;
    var grossCollectedPaisa = 0;

    for (final c in courses) {
      final courseBatches = batches.where((b) => b.courseId == c.id).map((b) => b.id).toList();
      var courseInvoiced = 0;
      var courseCollected = 0;

      if (courseBatches.isNotEmpty) {
        final vouchers = await (_db.select(_db.feeVouchersTable)
              ..where((v) => v.batchId.isIn(courseBatches)))
            .get();
        courseInvoiced = vouchers.fold(0, (sum, v) => sum + v.totalDuePaisa);
        courseCollected = vouchers.fold(0, (sum, v) => sum + v.amountPaidPaisa);
      }

      final coursePending = courseInvoiced - courseCollected;
      grossInvoicedPaisa += courseInvoiced;
      grossCollectedPaisa += courseCollected;

      rows.add([
        c.code ?? '',
        c.name,
        '${courseBatches.length}',
        Money.fromPaisa(courseInvoiced).format(),
        Money.fromPaisa(courseCollected).format(),
        Money.fromPaisa(coursePending).format(),
      ]);
    }

    final grossPendingPaisa = grossInvoicedPaisa - grossCollectedPaisa;

    return ReportData(
      type: filter.reportType,
      title: 'Course-wise Fee Summary',
      subtitle: 'Course tuition billing, collections, and outstanding ledger',
      headers: const ['Course Code', 'Course Name', 'Batches', 'Invoiced', 'Collected', 'Pending'],
      rows: rows,
      summaryMetrics: {
        'Total Invoiced': Money.fromPaisa(grossInvoicedPaisa).format(),
        'Total Collected': Money.fromPaisa(grossCollectedPaisa).format(),
        'Total Pending': Money.fromPaisa(grossPendingPaisa).format(),
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // 12. Audit Log & Cryptographic Verification
  // ---------------------------------------------------------------------------
  Future<ReportData> _buildAuditLog(ReportFilter filter, DateTime now) async {
    final rowsData = await (_db.select(_db.auditLogTable)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(500))
        .get();

    final entries = rowsData.reversed.map((r) => AuditEntry(
      id: r.id,
      action: r.action,
      entityType: r.entityType,
      entityId: r.entityId,
      userId: r.userId,
      createdAt: r.createdAt,
      details: r.details,
      previousHash: r.previousHash,
      entryHash: r.entryHash,
    )).toList();

    final verifyRes = verifyAuditChain(entries);
    final isChainIntact = verifyRes.fold(onSuccess: (_) => true, onFailure: (_) => false);

    final rows = rowsData.map((r) {
      final prevShort = r.previousHash.length > 8 ? '${r.previousHash.substring(0, 8)}...' : r.previousHash;
      final hashShort = r.entryHash.length > 8 ? '${r.entryHash.substring(0, 8)}...' : r.entryHash;
      final ts = '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')} ${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
      return [
        '#${r.id}',
        ts,
        r.action,
        r.entityType,
        'User #${r.userId}',
        prevShort,
        hashShort,
      ];
    }).toList();

    return ReportData(
      type: filter.reportType,
      title: 'Audit Log & Cryptographic Verification',
      subtitle: 'SHA-256 hash-chained financial and system event register',
      headers: const ['ID', 'Timestamp', 'Action', 'Entity', 'User', 'Prev Hash', 'Entry Hash'],
      rows: rows,
      summaryMetrics: {
        'Total Events': '${rowsData.length}',
        'Chain Integrity': isChainIntact ? 'VERIFIED (Intact)' : 'TAMPERED / BROKEN',
      },
      generatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // PDF Generator (A4 Landscape & 80mm Thermal Slip)
  // ---------------------------------------------------------------------------
  @override
  Future<Result<List<int>>> generatePdfBytes(
    ReportData data, {
    String academyName = 'ClassKhata Academy',
    bool isThermal = false,
  }) async {
    try {
      final doc = pw.Document();

      if (isThermal) {
        // 80mm Roll Thermal Receipt / Slip
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.all(12),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      academyName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      data.title,
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Date: ${data.generatedAt.day}/${data.generatedAt.month}/${data.generatedAt.year}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ),
                  pw.Divider(thickness: 0.8),
                  if (data.summaryMetrics.isNotEmpty) ...[
                    pw.Text('SUMMARY METRICS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...data.summaryMetrics.entries.map((e) => pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(e.value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    )),
                    pw.Divider(thickness: 0.8),
                  ],
                  pw.Text('RECORDS (${data.rows.length})', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ...data.rows.take(25).map((r) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text(r.isNotEmpty ? r[0] : '', style: const pw.TextStyle(fontSize: 7))),
                        pw.Text(r.length > 3 ? r[3] : (r.isNotEmpty ? r.last : ''), style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  )),
                  if (data.rows.length > 25)
                    pw.Center(
                      child: pw.Text('...and ${data.rows.length - 25} more records', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ),
                  pw.Divider(thickness: 0.8),
                  pw.Center(
                    child: pw.Text('ClassKhata Desktop System', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ),
                ],
              );
            },
          ),
        );
      } else {
        // Landscape A4 Page
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            header: (context) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 1.5)),
                ),
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(academyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 2),
                        pw.Text(data.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        pw.Text(data.subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('OFFICIAL REPORT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Date: ${data.generatedAt.day}/${data.generatedAt.month}/${data.generatedAt.year}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
              );
            },
            footer: (context) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(top: 12),
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ClassKhata Financial Management Application', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              );
            },
            build: (context) {
              return [
                if (data.rows.isEmpty)
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(32),
                      child: pw.Text('No records matching the filter criteria.', style: const pw.TextStyle(color: PdfColors.grey600)),
                    ),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headers: data.headers,
                    data: data.rows,
                    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                  ),
                if (data.summaryMetrics.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: data.summaryMetrics.entries.map((e) {
                        return pw.Column(
                          children: [
                            pw.Text(e.key, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 3),
                            pw.Text(e.value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ];
            },
          ),
        );
      }

      final bytes = await doc.save();
      return Success(bytes);
    } catch (e, st) {
      await AppLogger.instance.error('generatePdfBytes error', error: e, stack: st);
      return Failure(UnexpectedFailure('Failed to generate PDF: ${e.toString()}'));
    }
  }

  // ---------------------------------------------------------------------------
  // Excel (.xlsx) Export with Formula Injection Sanitization
  // ---------------------------------------------------------------------------
  @override
  Future<Result<String>> exportToExcel(ReportData data, {String? targetDirectory}) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'ClassKhata_Report';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // 1. Report Title & Subtitle
      sheet.appendRow([TextCellValue(sanitizeExcelCell(data.title))]);
      sheet.appendRow([TextCellValue(sanitizeExcelCell(data.subtitle))]);
      sheet.appendRow([TextCellValue(sanitizeExcelCell('Generated: ${data.generatedAt.toIso8601String()}'))]);
      sheet.appendRow([]); // Empty spacer row

      // 2. Headers (Sanitized against formula injection)
      final headerCells = data.headers.map((h) => TextCellValue(sanitizeExcelCell(h))).toList();
      sheet.appendRow(headerCells);

      // 3. Data Rows (Every cell is sanitized)
      for (final row in data.rows) {
        final cellRow = row.map((cell) => TextCellValue(sanitizeExcelCell(cell))).toList();
        sheet.appendRow(cellRow);
      }

      // 4. Summary metrics
      if (data.summaryMetrics.isNotEmpty) {
        sheet.appendRow([]); // Empty spacer
        sheet.appendRow([TextCellValue('SUMMARY METRICS')]);
        data.summaryMetrics.forEach((k, v) {
          sheet.appendRow([TextCellValue(sanitizeExcelCell(k)), TextCellValue(sanitizeExcelCell(v))]);
        });
      }

      // 5. Determine target save directory
      Directory exportDir;
      if (targetDirectory != null && targetDirectory.isNotEmpty) {
        exportDir = Directory(targetDirectory);
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        exportDir = Directory(p.join(docsDir.path, 'ClassKhata_Exports'));
      }

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final sanitizedFilename = '${data.type.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fullPath = p.join(exportDir.path, sanitizedFilename);

      final encodedBytes = excel.encode();
      if (encodedBytes == null) {
        return const Failure(UnexpectedFailure('Failed to encode Excel spreadsheet.'));
      }

      final file = File(fullPath);
      await file.writeAsBytes(encodedBytes);

      return Success(fullPath);
    } catch (e, st) {
      await AppLogger.instance.error('exportToExcel error', error: e, stack: st);
      return Failure(UnexpectedFailure('Failed to export Excel file: ${e.toString()}'));
    }
  }
}
