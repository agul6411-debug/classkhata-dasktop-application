import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/fees/data/datasources/fee_dao.dart';
import 'package:classkhata/features/fees/data/repositories/fee_repository_impl.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FeeDao feeDao;
  late FeeRepositoryImpl feeRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    feeDao = FeeDao(db);
    feeRepo = FeeRepositoryImpl(feeDao);

    // Seed session, course, batch
    await db.into(db.academicSessionsTable).insert(
          AcademicSessionsTableCompanion.insert(
            name: '2026-2027',
            startDate: DateTime(2026),
            endDate: DateTime(2026, 12, 31),
          ),
        );
    await db.into(db.coursesTable).insert(
          CoursesTableCompanion.insert(name: 'Class 9th'),
        );
    await db.into(db.batchesTable).insert(
          BatchesTableCompanion.insert(
            sessionId: 1,
            courseId: 1,
            name: 'Section A - 9th',
            monthlyFeePaisa: const Value(500000), // Rs. 5,000
            dueDay: const Value(10),
          ),
        );

    // Seed 2 students
    await db.into(db.studentsTable).insert(
          StudentsTableCompanion.insert(
            rollNumber: 'STD-0001',
            batchId: 1,
            name: 'Ahmad Khan',
            guardianPhone: '03001234567',
          ),
        );
    await db.into(db.studentsTable).insert(
          StudentsTableCompanion.insert(
            rollNumber: 'STD-0002',
            batchId: 1,
            name: 'Fatima Noor',
            guardianPhone: '03009876543',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Atomic Fee Transactions, Receipts & Idempotent Vouchers', () {
    test('generateBatchVouchers is idempotent (running twice produces no duplicates)', () async {
      // First run: generates vouchers for 2 students
      final count1 = await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      expect(count1, equals(2));

      final vouchersAfterRun1 = await feeDao.getVouchers(batchId: 1, monthYear: '2026-10');
      expect(vouchersAfterRun1.length, equals(2));

      // Second run: same batch and monthYear
      final count2 = await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      expect(count2, equals(0)); // 0 new vouchers created

      final vouchersAfterRun2 = await feeDao.getVouchers(batchId: 1, monthYear: '2026-10');
      expect(vouchersAfterRun2.length, equals(2)); // No duplicates
    });

    test('collectFeeTransaction generates sequential gap-free receipt numbers inside atomic transaction', () async {
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );

      final vouchers = await feeDao.getVouchers(batchId: 1);
      final v1 = vouchers.first;
      final v2 = vouchers.last;

      // 1. Payment 1 -> Receipt RCP-000001
      final res1 = await feeRepo.collectFee(
        voucherId: v1.id,
        studentId: v1.studentId,
        amount: const Money(500000), // Rs 5000
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.valueOrThrow.receipt.receiptNumber, equals('RCP-000001'));
      expect(res1.valueOrThrow.updatedVoucher.status, equals(VoucherStatus.paid));
      expect(res1.valueOrThrow.receipt.qrData, contains('RCP-000001'));

      // 2. Payment 2 -> Receipt RCP-000002 (strictly sequential, no gaps)
      final res2 = await feeRepo.collectFee(
        voucherId: v2.id,
        studentId: v2.studentId,
        amount: const Money(200000), // Partial Rs 2000
        paymentMode: 'bank',
        referenceNumber: 'TXN-998811',
        createdBy: 1,
      );
      expect(res2.isSuccess, isTrue);
      expect(res2.valueOrThrow.receipt.receiptNumber, equals('RCP-000002'));
      expect(res2.valueOrThrow.updatedVoucher.status, equals(VoucherStatus.partial));
    });

    test('collectFeeTransaction rolls back cleanly on error without burning a receipt number', () async {
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      final vouchers = await feeDao.getVouchers(batchId: 1);
      final v1 = vouchers.first;

      // Collect payment 1 successfully -> RCP-000001
      final res1 = await feeRepo.collectFee(
        voucherId: v1.id,
        studentId: v1.studentId,
        amount: const Money(200000),
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(res1.valueOrThrow.receipt.receiptNumber, equals('RCP-000001'));

      // Attempt to collect fee for a non-existent voucher (triggers database transaction exception & rollback)
      final failedRes = await feeRepo.collectFee(
        voucherId: 99999, // Does not exist
        studentId: v1.studentId,
        amount: const Money(100000),
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(failedRes.isFailure, isTrue);

      // Verify the receipt counter was rolled back: the next valid payment MUST receive RCP-000002, not RCP-000003!
      final resNext = await feeRepo.collectFee(
        voucherId: v1.id,
        studentId: v1.studentId,
        amount: const Money(300000),
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(resNext.isSuccess, isTrue);
      expect(resNext.valueOrThrow.receipt.receiptNumber, equals('RCP-000002'));
    });

    test('cancelVoucher applies soft reversal with audit log and reason (no hard delete)', () async {
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );
      final vouchers = await feeDao.getVouchers(batchId: 1);
      final v1 = vouchers.first;

      // Cancel the voucher
      final cancelRes = await feeRepo.cancelVoucher(
        voucherId: v1.id,
        reason: 'Duplicate voucher created in error',
        cancelledBy: 1,
      );
      expect(cancelRes.isSuccess, isTrue);

      // Verify row is still in database with status 'cancelled'
      final cancelledVoucher = await feeDao.getVoucherById(v1.id);
      expect(cancelledVoucher, isNotNull);
      expect(cancelledVoucher!.status, equals('cancelled'));
      expect(cancelledVoucher.reversalReason, equals('Duplicate voucher created in error'));
      expect(cancelledVoucher.reversedBy, equals(1));

      // Verify audit log entry was written
      final auditLogs = await db.select(db.auditLogTable).get();
      expect(auditLogs.any((a) => a.action == 'voucher.cancelled' && a.entityId == v1.id.toString()), isTrue);
    });

    test('unpaid balance is carried forward into subsequent monthly vouchers', () async {
      // Month 1: October
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-10',
        dueDate: DateTime(2026, 10, 10),
        createdBy: 1,
      );

      final octVouchers = await feeDao.getVouchers(batchId: 1, monthYear: '2026-10');
      final octV1 = octVouchers.first; // Total due Rs 5,000

      // Student pays only Rs 3,000 (leaves Rs 2,000 unpaid)
      await feeRepo.collectFee(
        voucherId: octV1.id,
        studentId: octV1.studentId,
        amount: const Money(300000),
        paymentMode: 'cash',
        createdBy: 1,
      );

      // Month 2: November
      await feeDao.generateBatchVouchers(
        batchId: 1,
        monthYear: '2026-11',
        dueDate: DateTime(2026, 11, 10),
        createdBy: 1,
      );

      final novVouchers = await feeDao.getVouchers(batchId: 1, monthYear: '2026-11');
      final novV1 = novVouchers.firstWhere((v) => v.studentId == octV1.studentId);

      // Base is 5,000 + CarryForward is 2,000 -> Total Due is Rs 7,000 (700,000 paisa)
      expect(novV1.carryForwardPaisa, equals(200000));
      expect(novV1.totalDuePaisa, equals(700000));
    });
  });
}
