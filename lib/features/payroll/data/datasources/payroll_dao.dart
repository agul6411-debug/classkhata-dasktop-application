/// Payroll DAO executing transactional payroll runs, advance recoveries, and cash book outflows.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_chain.dart';
import '../../domain/entities/payroll_entities.dart';

class PayrollDao {
  final AppDatabase _db;
  const PayrollDao(this._db);

  AppDatabase get db => _db;

  // ---------------------------------------------------------------------------
  // Staff Members
  // ---------------------------------------------------------------------------

  Future<List<StaffMembersTableData>> getStaffMembers({StaffStatus? status}) {
    final query = _db.select(_db.staffMembersTable);
    if (status != null) {
      query.where((t) => t.status.equals(status.name));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.staffCode)]);
    return query.get();
  }

  Future<int> insertStaff(StaffMembersTableCompanion companion) =>
      _db.into(_db.staffMembersTable).insert(companion);

  Future<String> getNextStaffCode() async {
    final count = await _db.select(_db.staffMembersTable).get();
    final nextNumber = count.length + 1;
    return 'STF-${nextNumber.toString().padLeft(4, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Salary Structures
  // ---------------------------------------------------------------------------

  Future<SalaryStructuresTableData?> getSalaryStructure(int staffId) =>
      (_db.select(_db.salaryStructuresTable)
            ..where((t) => t.staffId.equals(staffId) & t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setSalaryStructure(SalaryStructuresTableCompanion companion) async {
    await _db.transaction(() async {
      // Deactivate old active structure
      await (_db.update(_db.salaryStructuresTable)
            ..where((t) => t.staffId.equals(companion.staffId.value)))
          .write(const SalaryStructuresTableCompanion(isActive: Value(false)));

      await _db.into(_db.salaryStructuresTable).insert(companion);
    });
  }

  // ---------------------------------------------------------------------------
  // Monthly Payroll Run (Atomic Transaction)
  // ---------------------------------------------------------------------------

  Future<int> runMonthlyPayrollTransaction({
    required String monthYear,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      final activeStaff = await (_db.select(_db.staffMembersTable)
            ..where((t) => t.status.equals('active')))
          .get();

      int generatedCount = 0;

      for (final staff in activeStaff) {
        // Skip if already generated for this month
        final existingRun = await (_db.select(_db.payrollRunsTable)
              ..where((t) => t.staffId.equals(staff.id) & t.monthYear.equals(monthYear)))
            .getSingleOrNull();

        if (existingRun != null) continue;

        // Get salary structure
        final structure = await (_db.select(_db.salaryStructuresTable)
              ..where((t) => t.staffId.equals(staff.id) & t.isActive.equals(true)))
            .getSingleOrNull();

        if (structure == null) continue;

        // Check for active advance recovery
        final advances = await (_db.select(_db.staffAdvancesTable)
              ..where((t) => t.staffId.equals(staff.id) & t.remainingPaisa.isBiggerThanValue(0)))
            .get();

        int advanceRecovery = 0;
        if (advances.isNotEmpty) {
          final adv = advances.first;
          // Recover up to 20% of base salary or remaining advance
          final maxRecoverable = (structure.baseAmountPaisa * 0.2).round();
          advanceRecovery = adv.remainingPaisa < maxRecoverable ? adv.remainingPaisa : maxRecoverable;

          // Update advance remaining
          await (_db.update(_db.staffAdvancesTable)..where((t) => t.id.equals(adv.id))).write(
            StaffAdvancesTableCompanion(
              recoveredPaisa: Value(adv.recoveredPaisa + advanceRecovery),
              remainingPaisa: Value(adv.remainingPaisa - advanceRecovery),
            ),
          );
        }

        final base = structure.baseAmountPaisa;
        final allowances = structure.allowancesPaisa;
        final deductions = structure.deductionsPaisa;
        final gross = base + allowances;
        final net = gross - deductions - advanceRecovery;

        await _db.into(_db.payrollRunsTable).insert(
              PayrollRunsTableCompanion.insert(
                monthYear: monthYear,
                staffId: staff.id,
                baseSalaryPaisa: base,
                allowancesPaisa: Value(allowances),
                deductionsPaisa: Value(deductions),
                advanceRecoveryPaisa: Value(advanceRecovery),
                netSalaryPaisa: net > 0 ? net : 0,
                status: const Value('unpaid'),
                createdBy: Value(createdBy),
              ),
            );

        generatedCount++;
      }

      return generatedCount;
    });
  }

  // ---------------------------------------------------------------------------
  // Disburse / Pay Salary (Atomic: Update Run + Cash Book Outflow + Audit)
  // ---------------------------------------------------------------------------

  Future<void> paySalaryTransaction({
    required int payrollRunId,
    required String paymentMode,
    required int paidBy,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();

      // 1. Fetch payroll run
      final run = await (_db.select(_db.payrollRunsTable)..where((t) => t.id.equals(payrollRunId))).getSingle();
      final staff = await (_db.select(_db.staffMembersTable)..where((t) => t.id.equals(run.staffId))).getSingle();

      // 2. Mark payroll run as paid
      await (_db.update(_db.payrollRunsTable)..where((t) => t.id.equals(payrollRunId))).write(
        PayrollRunsTableCompanion(
          status: const Value('paid'),
          paidAt: Value(now),
          paymentMode: Value(paymentMode),
        ),
      );

      // 3. Insert Cash Book Outflow
      await _db.into(_db.cashBookEntriesTable).insert(
            CashBookEntriesTableCompanion.insert(
              entryType: 'outflow',
              category: 'salary',
              amountPaisa: run.netSalaryPaisa,
              description: 'Salary disbursed to ${staff.name} (${run.monthYear})',
              paymentMode: Value(paymentMode),
              referenceId: Value(payrollRunId),
              entryDate: Value(now),
              createdBy: Value(paidBy),
            ),
          );

      // 4. Hash-chained audit entry
      final lastAudit = await (_db.select(_db.auditLogTable)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

      final prevHash = lastAudit?.entryHash ?? 'GENESIS';
      final details = 'Salary paid to ${staff.name} for ${run.monthYear} amount Rs. ${(run.netSalaryPaisa / 100).toStringAsFixed(2)}';

      final entryHash = computeAuditHash(
        action: 'payroll.disbursed',
        entityType: 'PayrollRun',
        entityId: payrollRunId.toString(),
        userId: paidBy,
        createdAt: now,
        details: details,
        previousHash: prevHash,
      );

      await _db.into(_db.auditLogTable).insert(
            AuditLogTableCompanion.insert(
              action: 'payroll.disbursed',
              entityType: 'PayrollRun',
              entityId: Value(payrollRunId.toString()),
              userId: paidBy,
              createdAt: Value(now),
              details: Value(details),
              previousHash: prevHash,
              entryHash: entryHash,
            ),
          );
    });
  }

  Future<List<PayrollRunsTableData>> getPayrollRuns({String? monthYear}) {
    final query = _db.select(_db.payrollRunsTable);
    if (monthYear != null) query.where((t) => t.monthYear.equals(monthYear));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Advances
  // ---------------------------------------------------------------------------

  Future<List<StaffAdvancesTableData>> getStaffAdvances({int? staffId}) {
    final query = _db.select(_db.staffAdvancesTable);
    if (staffId != null) query.where((t) => t.staffId.equals(staffId));
    query.orderBy([(t) => OrderingTerm.desc(t.issueDate)]);
    return query.get();
  }

  Future<int> insertAdvance(StaffAdvancesTableCompanion companion) =>
      _db.into(_db.staffAdvancesTable).insert(companion);
}
