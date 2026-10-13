import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/academics/domain/entities/academic_entities.dart';
import 'package:classkhata/features/academics/domain/repositories/academic_repository.dart';
import 'package:classkhata/features/dashboard/domain/entities/dashboard_kpis.dart';
import 'package:classkhata/features/dashboard/domain/usecases/get_dashboard_kpis_usecase.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:classkhata/features/fees/domain/repositories/fee_repository.dart';
import 'package:classkhata/features/students/domain/entities/student_entities.dart';
import 'package:classkhata/features/students/domain/repositories/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
      const kpis = DashboardKpis(
        monthYear: '2026-10',
        expectedTotal: Money(0),
        collectedTotal: Money(0),
        pendingTotal: Money(0),
        overdueTotal: Money(0),
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

    test('GetDashboardKpisUseCase returns active students count even if vouchers fail', () async {
      final useCase = GetDashboardKpisUseCase(
        feeRepo: _MockFailingFeeRepository(),
        studentRepo: _MockStudentRepository(),
        academicRepo: _MockAcademicRepository(),
      );

      final result = await useCase('2026-10');
      expect(result.isSuccess, isTrue);
      final kpis = result.valueOrThrow;
      expect(kpis.studentsCount, 3);
      expect(kpis.coursesCount, 2);
      expect(kpis.batchesCount, 2);
      expect(kpis.expectedTotal.paisa, 0);
    });
  });
}

class _MockFailingFeeRepository implements FeeRepository {
  @override
  Future<Result<List<FeeVoucher>>> getVouchers({int? batchId, int? studentId, String? monthYear, VoucherStatus? status}) async {
    return const Failure(DatabaseFailure('No vouchers table'));
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStudentRepository implements StudentRepository {
  @override
  Future<Result<List<Student>>> getStudents({int? batchId, String? query, StudentStatus? status}) async {
    return Success([
      Student(id: 1, rollNumber: 'STD-0001', batchId: 1, name: 'Ali', guardianPhone: '03001', joiningDate: DateTime.now(), status: StudentStatus.active),
      Student(id: 2, rollNumber: 'STD-0002', batchId: 1, name: 'Sara', guardianPhone: '03002', joiningDate: DateTime.now(), status: StudentStatus.active),
      Student(id: 3, rollNumber: 'STD-0003', batchId: 2, name: 'Bilal', guardianPhone: '03003', joiningDate: DateTime.now(), status: StudentStatus.active),
    ]);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAcademicRepository implements AcademicRepository {
  @override
  Future<Result<List<Course>>> getCourses() async {
    return const Success([Course(id: 1, name: 'Class 9'), Course(id: 2, name: 'Class 10')]);
  }
  @override
  Future<Result<List<Batch>>> getBatches({int? sessionId, int? courseId}) async {
    return const Success([
      Batch(id: 1, sessionId: 1, courseId: 1, name: 'Section A', monthlyFee: Money(300000), dueDay: 10, isActive: true),
      Batch(id: 2, sessionId: 1, courseId: 2, name: 'Section B', monthlyFee: Money(350000), dueDay: 10, isActive: true),
    ]);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
