import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/finance/data/datasources/finance_dao.dart';
import 'package:classkhata/features/payroll/data/datasources/payroll_dao.dart';
import 'package:classkhata/features/payroll/data/repositories/payroll_repository_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PayrollDao payrollDao;
  late PayrollRepositoryImpl payrollRepo;
  late FinanceDao financeDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    payrollDao = PayrollDao(db);
    payrollRepo = PayrollRepositoryImpl(payrollDao);
    financeDao = FinanceDao(db);

    // 1. Seed active staff member
    final staffId = await payrollDao.insertStaff(
      StaffMembersTableCompanion.insert(
        staffCode: 'STF-0001',
        name: 'Tariq Mehmood',
        phone: '03001234567',
        designation: 'Senior Math Teacher',
        status: const Value('active'),
      ),
    );

    // 2. Seed salary structure: Rs 50,000 base, Rs 5,000 allowance, Rs 2,000 deduction
    await payrollDao.setSalaryStructure(
      SalaryStructuresTableCompanion.insert(
        staffId: staffId,
        structureType: const Value('fixed'),
        baseAmountPaisa: const Value(5000000), // Rs 50,000
        allowancesPaisa: const Value(500000),  // Rs 5,000
        deductionsPaisa: const Value(200000),  // Rs 2,000
      ),
    );

    // 3. Seed staff advance: Rs 20,000 advance
    await db.into(db.staffAdvancesTable).insert(
          StaffAdvancesTableCompanion.insert(
            staffId: staffId,
            amountPaisa: 2000000,
            recoveredPaisa: const Value(0),
            remainingPaisa: 2000000, // Rs 20,000
            reason: const Value('Medical emergency'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Payroll Transactions, Advance Recovery & Cash Book Outflow', () {
    test('runMonthlyPayrollTransaction auto-deducts advance and avoids duplicate runs', () async {
      // 1. Run payroll for 2026-10
      // Base: 50,000, Allowances: 5,000, Deductions: 2,000
      // 20% max advance recovery: 50,000 * 0.2 = Rs 10,000 (1,000,000 paisa)
      // Net pay = (50,000 + 5,000) - 2,000 - 10,000 = Rs 43,000 (4,300,000 paisa)
      final count = await payrollDao.runMonthlyPayrollTransaction(
        monthYear: '2026-10',
        createdBy: 1,
      );
      expect(count, equals(1));

      final runs = await payrollRepo.getPayrollRuns(monthYear: '2026-10');
      expect(runs.isSuccess, isTrue);
      expect(runs.valueOrThrow.length, equals(1));

      final run = runs.valueOrThrow.first;
      expect(run.baseSalary.paisa, equals(5000000));
      expect(run.allowances.paisa, equals(500000));
      expect(run.deductions.paisa, equals(200000));
      expect(run.advanceRecovery.paisa, equals(1000000)); // Recovered 10,000
      expect(run.netSalary.paisa, equals(4300000)); // Rs 43,000 net
      expect(run.status, equals('unpaid'));

      // Check updated advance remaining: 20,000 - 10,000 = 10,000 remaining
      final advances = await payrollRepo.getStaffAdvances(staffId: run.staffId);
      expect(advances.valueOrThrow.first.remaining.paisa, equals(1000000));
      expect(advances.valueOrThrow.first.recovered.paisa, equals(1000000));

      // 2. Idempotency: running payroll again for 2026-10 must not create duplicate entries
      final countAgain = await payrollDao.runMonthlyPayrollTransaction(
        monthYear: '2026-10',
        createdBy: 1,
      );
      expect(countAgain, equals(0)); // 0 new runs created

      final runsAgain = await payrollRepo.getPayrollRuns(monthYear: '2026-10');
      expect(runsAgain.valueOrThrow.length, equals(1));
    });

    test('paySalaryTransaction marks run as paid and records Cash Book Outflow atomically', () async {
      await payrollDao.runMonthlyPayrollTransaction(
        monthYear: '2026-10',
        createdBy: 1,
      );
      final run = (await payrollRepo.getPayrollRuns(monthYear: '2026-10')).valueOrThrow.first;

      // Disburse salary
      final payRes = await payrollRepo.paySalary(
        payrollRunId: run.id,
        paymentMode: 'bank',
        paidBy: 1,
      );
      expect(payRes.isSuccess, isTrue);

      // Verify payroll run is marked 'paid'
      final updatedRuns = await payrollRepo.getPayrollRuns(monthYear: '2026-10');
      final updatedRun = updatedRuns.valueOrThrow.first;
      expect(updatedRun.status, equals('paid'));
      expect(updatedRun.paidAt, isNotNull);

      // Verify matching Cash Book Outflow was created in the same transaction
      final cashEntries = await financeDao.getCashBookEntries();
      expect(cashEntries.length, equals(1));
      expect(cashEntries.first.entryType, equals('outflow'));
      expect(cashEntries.first.category, equals('salary'));
      expect(cashEntries.first.amountPaisa, equals(updatedRun.netSalary.paisa));
      expect(cashEntries.first.paymentMode, equals('bank'));
      expect(cashEntries.first.description, contains('Tariq Mehmood'));
    });
  });
}
