import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/core/utils/validators.dart';
import 'package:classkhata/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:classkhata/features/reports/domain/entities/report_entities.dart';

void main() {
  late AppDatabase db;
  late ReportsRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ReportsRepositoryImpl(db);

    // Seed Academic Session
    final sessionId = await db.into(db.academicSessionsTable).insert(
          AcademicSessionsTableCompanion.insert(
            name: '2026-2027',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31),
          ),
        );

    // Seed Courses
    final courseId = await db.into(db.coursesTable).insert(
          CoursesTableCompanion.insert(
            code: const Value('CS101'),
            name: 'Computer Science',
          ),
        );

    // Seed Batches
    final batchId = await db.into(db.batchesTable).insert(
          BatchesTableCompanion.insert(
            sessionId: sessionId,
            courseId: courseId,
            name: 'Morning Alpha',
            timing: const Value('08:00 - 10:00'),
            duration: const Value('6 Months'),
            monthlyFeePaisa: const Value(600000),
            dueDay: const Value(10),
          ),
        );

    // Seed Students
    final studentId = await db.into(db.studentsTable).insert(
          StudentsTableCompanion.insert(
            rollNumber: 'STD-0001',
            name: 'Bilal Ahmed',
            guardianPhone: '03001234567',
            batchId: batchId,
            joiningDate: Value(DateTime(2026, 1, 1)),
          ),
        );

    // Seed Fee Vouchers (One paid Rs. 6,000, one partial Rs. 4,000 paid / 6,000 due)
    await db.into(db.feeVouchersTable).insert(
          FeeVouchersTableCompanion.insert(
            voucherNumber: 'VOU-0001',
            studentId: studentId,
            batchId: batchId,
            monthYear: '2026-03',
            issueDate: DateTime(2026, 3, 1),
            dueDate: DateTime(2026, 3, 10),
            baseAmountPaisa: const Value(600000),
            totalDuePaisa: const Value(600000),
            amountPaidPaisa: const Value(600000),
            status: const Value('paid'),
          ),
        );

    await db.into(db.feeVouchersTable).insert(
          FeeVouchersTableCompanion.insert(
            voucherNumber: 'VOU-0002',
            studentId: studentId,
            batchId: batchId,
            monthYear: '2026-04',
            issueDate: DateTime(2026, 4, 1),
            dueDate: DateTime(2026, 4, 10),
            baseAmountPaisa: const Value(600000),
            totalDuePaisa: const Value(600000),
            amountPaidPaisa: const Value(400000),
            status: const Value('partial'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Consolidated Reports & Raw Data Accuracy', () {
    test('Batch-wise fee report matches raw voucher aggregates exactly', () async {
      final res = await repo.buildReport(
        ReportFilter(
          reportType: ReportType.batchWiseFees,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        ),
      );

      expect(res.isSuccess, isTrue);
      final report = res.valueOrThrow;

      expect(report.rows.length, equals(1));
      final batchRow = report.rows.first;

      // Invoiced: 6,000 + 6,000 = 12,000
      // Collected: 6,000 + 4,000 = 10,000
      // Pending: 12,000 - 10,000 = 2,000
      expect(batchRow[0], equals('Morning Alpha'));
      expect(batchRow[2], equals('2')); // 2 vouchers
      expect(batchRow[3], equals(Money.fromPaisa(1200000).format()));
      expect(batchRow[4], equals(Money.fromPaisa(1000000).format()));
      expect(batchRow[5], equals(Money.fromPaisa(200000).format()));

      expect(report.summaryMetrics['Total Invoiced'], equals(Money.fromPaisa(1200000).format()));
      expect(report.summaryMetrics['Total Collected'], equals(Money.fromPaisa(1000000).format()));
      expect(report.summaryMetrics['Total Pending'], equals(Money.fromPaisa(200000).format()));
    });

    test('Course-wise fee report matches raw course aggregates accurately', () async {
      final res = await repo.buildReport(
        ReportFilter(
          reportType: ReportType.courseWiseFees,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        ),
      );

      expect(res.isSuccess, isTrue);
      final report = res.valueOrThrow;

      expect(report.rows.length, equals(1));
      final courseRow = report.rows.first;

      expect(courseRow[0], equals('CS101'));
      expect(courseRow[1], equals('Computer Science'));
      expect(courseRow[3], equals(Money.fromPaisa(1200000).format()));
      expect(courseRow[4], equals(Money.fromPaisa(1000000).format()));
      expect(courseRow[5], equals(Money.fromPaisa(200000).format()));
    });

    test('Generates thermal 80mm PDF roll bytes without failure', () async {
      final reportRes = await repo.buildReport(
        ReportFilter(
          reportType: ReportType.batchWiseFees,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        ),
      );

      final pdfRes = await repo.generatePdfBytes(
        reportRes.valueOrThrow,
        academyName: 'National Academy',
        isThermal: true,
      );

      expect(pdfRes.isSuccess, isTrue);
      expect(pdfRes.valueOrThrow.isNotEmpty, isTrue);
    });

    test('sanitizeExcelCell prevents formula injection on dangerous cell contents', () {
      expect(sanitizeExcelCell('=SUM(A1:A10)'), equals("'=SUM(A1:A10)"));
      expect(sanitizeExcelCell('+CMD|/C calc.exe'), equals("'+CMD|/C calc.exe"));
      expect(sanitizeExcelCell('-1234'), equals("'-1234"));
      expect(sanitizeExcelCell('@SUM'), equals("'@SUM"));
      expect(sanitizeExcelCell('Standard Name'), equals('Standard Name'));
    });
  });
}
