import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/academics/data/datasources/academic_dao.dart';
import 'package:classkhata/features/academics/data/repositories/academic_repository_impl.dart';
import 'package:classkhata/features/dashboard/domain/usecases/get_dashboard_kpis_usecase.dart';
import 'package:classkhata/features/fees/data/datasources/fee_dao.dart';
import 'package:classkhata/features/fees/data/repositories/fee_repository_impl.dart';
import 'package:classkhata/features/finance/data/datasources/finance_dao.dart';
import 'package:classkhata/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:classkhata/features/finance/domain/usecases/finance_usecases.dart';
import 'package:classkhata/features/students/data/datasources/student_dao.dart';
import 'package:classkhata/features/students/data/repositories/student_repository_impl.dart';

void main() {
  late AppDatabase db;
  late FinanceDao financeDao;
  late FinanceRepositoryImpl financeRepo;
  late FeeDao feeDao;
  late FeeRepositoryImpl feeRepo;
  late StudentDao studentDao;
  late StudentRepositoryImpl studentRepo;
  late AcademicDao academicDao;
  late AcademicRepositoryImpl academicRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    financeDao = FinanceDao(db);
    financeRepo = FinanceRepositoryImpl(financeDao);
    feeDao = FeeDao(db);
    feeRepo = FeeRepositoryImpl(feeDao);
    studentDao = StudentDao(db);
    studentRepo = StudentRepositoryImpl(studentDao);
    academicDao = AcademicDao(db);
    academicRepo = AcademicRepositoryImpl(academicDao);

    // Seed academic setup
    await db.into(db.academicSessionsTable).insert(
          AcademicSessionsTableCompanion.insert(
            name: '2026-2027',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31),
          ),
        );
    await db.into(db.coursesTable).insert(
          CoursesTableCompanion.insert(name: 'General Science'),
        );
    await db.into(db.batchesTable).insert(
          BatchesTableCompanion.insert(
            sessionId: 1,
            courseId: 1,
            name: 'Morning Batch',
            monthlyFeePaisa: const Value(500000), // Rs. 5,000
            dueDay: const Value(10),
          ),
        );

    // Seed student
    await studentRepo.registerStudent(
      name: 'Usman Ali',
      batchId: 1,
      guardianPhone: '03001112233',
      createdBy: 1,
    );

    // Seed expense category
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(name: 'Utilities'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Finance & Cash Book Consistency', () {
    test('expense recording creates matching Cash Book Outflow entry', () async {
      final recordUseCase = RecordExpenseUseCase(financeRepo);

      final expResult = await recordUseCase(
        categoryId: 1,
        amount: const Money(150000), // Rs. 1,500
        description: 'Electricity Bill payment',
        paymentMode: 'cash',
        createdBy: 1,
      );

      expect(expResult.isSuccess, isTrue);
      expect(expResult.valueOrThrow.amount.paisa, equals(150000));

      // Verify Cash Book Outflow
      final cashEntries = await financeDao.getCashBookEntries();
      expect(cashEntries.length, equals(1));
      expect(cashEntries.first.entryType, equals('outflow'));
      expect(cashEntries.first.amountPaisa, equals(150000));
      expect(cashEntries.first.category, equals('expense'));
    });

    test('day-closing calculates expected cash, discrepancy, and locks the closed day', () async {
      final recordExpense = RecordExpenseUseCase(financeRepo);
      final dayClosingUseCase = DayClosingUseCase(financeRepo);

      final today = DateTime.now();

      // 1. Record expense: Rs 1,000 cash outflow
      await recordExpense(
        categoryId: 1,
        amount: const Money(100000),
        description: 'Office supplies',
        paymentMode: 'cash',
        createdBy: 1,
      );

      // 2. Collect fee payment: Rs 5,000 cash inflow
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      final v = (await feeDao.getVouchers(batchId: 1)).first;
      await feeRepo.collectFee(
        voucherId: v.id,
        studentId: v.studentId,
        amount: const Money(500000),
        paymentMode: 'cash',
        createdBy: 1,
      );

      // 3. Opening cash: Rs 2,000. Expected = 2,000 + 5,000 - 1,000 = Rs 6,000
      // Cash counted in drawer: Rs 5,800 (Discrepancy: -200 short)
      final closingRes = await dayClosingUseCase(
        date: today,
        openingCash: const Money(200000),
        actualCash: const Money(580000),
        discrepancyNote: 'Short by 200 PKR',
        closedBy: 1,
      );

      expect(closingRes.isSuccess, isTrue);
      final closing = closingRes.valueOrThrow;
      expect(closing.expectedClosingCash.paisa, equals(600000));
      expect(closing.actualCash.paisa, equals(580000));
      expect(closing.discrepancy.paisa, equals(-20000)); // -Rs 200
      expect(closing.hasDiscrepancy, isTrue);

      // 4. DAY LOCK: Attempting to close the same day a second time MUST fail
      final duplicateClosing = await dayClosingUseCase(
        date: today,
        openingCash: const Money(200000),
        actualCash: const Money(600000),
        closedBy: 1,
      );
      expect(duplicateClosing.isFailure, isTrue);
    });

    test('Profit & Loss summary calculates fee income, expenses and margin', () async {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 12, 31);

      // 1. Generate voucher and collect Rs 5,000 fee
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      final v = (await feeDao.getVouchers(batchId: 1)).first;
      await feeRepo.collectFee(
        voucherId: v.id,
        studentId: v.studentId,
        amount: const Money(500000),
        paymentMode: 'cash',
        createdBy: 1,
      );

      // 2. Record Rs 2,000 expense
      await RecordExpenseUseCase(financeRepo)(
        categoryId: 1,
        amount: const Money(200000),
        description: 'Internet bill',
        paymentMode: 'cash',
        createdBy: 1,
      );

      final pnl = await financeDao.getProfitLossSummary(
        from: from,
        to: to,
        periodName: 'Annual 2026',
      );

      expect(pnl.totalIncome.paisa, equals(500000));
      expect(pnl.totalExpenses.paisa, equals(200000));
      expect(pnl.netProfit.paisa, equals(300000)); // Rs 3,000
      expect(pnl.marginPercentage, equals(60.0)); // 3000 / 5000 * 100 = 60%
    });

    test('Dashboard aggregate queries match raw database sums', () async {
      final getKpis = GetDashboardKpisUseCase(
        feeRepo: feeRepo,
        studentRepo: studentRepo,
        academicRepo: academicRepo,
      );

      // Month: 2026-10
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );

      final v = (await feeDao.getVouchers(batchId: 1)).first;
      await feeRepo.collectFee(
        voucherId: v.id,
        studentId: v.studentId,
        amount: const Money(300000), // Paid Rs 3,000 of Rs 5,000
        paymentMode: 'cash',
        createdBy: 1,
      );

      final kpisRes = await getKpis('2026-10');
      expect(kpisRes.isSuccess, isTrue);

      final kpis = kpisRes.valueOrThrow;
      expect(kpis.expectedTotal.paisa, equals(500000));
      expect(kpis.collectedTotal.paisa, equals(300000));
      expect(kpis.pendingTotal.paisa, equals(200000));
      expect(kpis.studentsCount, equals(1));
      expect(kpis.batchesCount, equals(1));
      expect(kpis.coursesCount, equals(1));
      expect(kpis.partialCount, equals(1));
    });
  });
}
