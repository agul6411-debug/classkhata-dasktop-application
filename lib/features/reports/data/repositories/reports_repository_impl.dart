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

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final AppDatabase _db;
  const ReportsRepositoryImpl(this._db);

  @override
  Future<Result<ReportData>> buildReport(ReportFilter filter) async {
    try {
      final now = DateTime.now();
      switch (filter.reportType) {
        case ReportType.feeCollectionSummary:
          return Success(await _buildFeeCollectionSummary(filter, now));
        case ReportType.defaultersAging:
          return Success(await _buildDefaultersAging(filter, now));
        case ReportType.cashBookStatement:
          return Success(await _buildCashBookStatement(filter, now));
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

    final voucherMap = {for (var v in vouchers) v.id: v};
    final studentMap = {for (var s in students) s.id: s};
    final batchMap = {for (var b in batches) b.id: b.name};

    int totalAmountPaisa = 0;
    final rows = <List<String>>[];

    for (final r in receipts) {
      totalAmountPaisa += r.amountPaisa;
      final voucher = voucherMap[r.voucherId];
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
    final studentMap = {for (var s in students) s.id: s};
    final batchMap = {for (var b in batches) b.id: b.name};

    int totalOutstandingPaisa = 0;
    int count30 = 0;
    int count60 = 0;
    int count90 = 0;
    final rows = <List<String>>[];

    for (final v in unpaidVouchers) {
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
        e.paymentMode.toUpperCase(),
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
    for (var r in receipts) {
      totalIncomePaisa += r.amountPaisa;
    }

    // Group expenses by category
    final expenseCatTotals = <String, int>{};
    int totalExpensePaisa = 0;

    for (var o in outflows) {
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
    final query = _db.select(_db.payrollRunsTable);
    if (filter.monthYear != null && filter.monthYear!.isNotEmpty) {
      query.where((t) => t.monthYear.equals(filter.monthYear!));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final runs = await query.get();

    final staff = await _db.select(_db.staffMembersTable).get();
    final staffMap = {for (var s in staff) s.id: s};

    int totalNetSalaryPaisa = 0;
    final rows = <List<String>>[];

    for (final r in runs) {
      final s = staffMap[r.staffId];
      totalNetSalaryPaisa += r.netSalaryPaisa;

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
      ]);
    }

    return ReportData(
      type: filter.reportType,
      title: 'Monthly Payroll Register',
      subtitle: filter.monthYear != null ? 'Payroll for period ${filter.monthYear}' : 'All historical payroll records',
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
      ],
      rows: rows,
      summaryMetrics: {
        'Total Net Disbursed': Money.fromPaisa(totalNetSalaryPaisa).format(),
        'Staff Count': '${rows.length}',
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
    final catMap = {for (var c in categories) c.id: c.name};

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
    final itemMap = {for (var i in items) i.id: i.name};

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
    final supMap = {for (var s in suppliers) s.id: s.name};

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

    final batchMap = {for (var b in batches) b.id: b};
    final courseMap = {for (var c in courses) c.id: c.name};

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
  // PDF Generator
  // ---------------------------------------------------------------------------
  @override
  Future<Result<List<int>>> generatePdfBytes(ReportData data, {String academyName = 'ClassKhata Academy'}) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal, width: 1.5)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(academyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.SizedBox(height: 2),
                      pw.Text(data.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text(data.subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('OFFICIAL REPORT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
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
                          pw.Text(e.value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
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
