import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/academics/domain/entities/academic_entities.dart';
import 'package:classkhata/features/academics/domain/repositories/academic_repository.dart';
import 'package:classkhata/features/academics/domain/usecases/academic_usecases.dart';

// Mock repository for testing use case business rules
class MockAcademicRepository implements AcademicRepository {
  @override
  Future<Result<AcademicSession>> createSession({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    required int createdBy,
  }) async {
    return Success(AcademicSession(
      id: 1,
      name: name,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
    ));
  }

  @override
  Future<Result<Course>> createCourse({
    required String name,
    String? code,
    String? description,
    required int createdBy,
  }) async {
    return Success(Course(id: 1, name: name, code: code, description: description));
  }

  @override
  Future<Result<Batch>> createBatch({
    required int sessionId,
    required int courseId,
    required String name,
    String? instructorName,
    String? timing,
    String? duration,
    required int monthlyFeePaisa,
    required int dueDay,
    required int createdBy,
  }) async {
    return Success(Batch(
      id: 1,
      sessionId: sessionId,
      courseId: courseId,
      name: name,
      instructorName: instructorName,
      timing: timing,
      duration: duration,
      monthlyFee: Money.fromPaisa(monthlyFeePaisa),
      dueDay: dueDay,
      isActive: true,
    ));
  }

  @override
  Future<Result<List<AcademicSession>>> getSessions() async => const Success([]);

  @override
  Future<Result<void>> setCurrentSession(int sessionId) async => const Success(null);

  @override
  Future<Result<List<Course>>> getCourses() async => const Success([]);

  @override
  Future<Result<List<Batch>>> getBatches({int? sessionId, int? courseId}) async => const Success([]);

  @override
  Future<Result<void>> updateBatchStatus({required int batchId, required bool isActive}) async =>
      const Success(null);
}

void main() {
  late MockAcademicRepository repo;
  late CreateBatchUseCase createBatchUseCase;
  late CreateSessionUseCase createSessionUseCase;
  late CreateCourseUseCase createCourseUseCase;

  setUp(() {
    repo = MockAcademicRepository();
    createBatchUseCase = CreateBatchUseCase(repo);
    createSessionUseCase = CreateSessionUseCase(repo);
    createCourseUseCase = CreateCourseUseCase(repo);
  });

  group('Academic Use Cases', () {
    test('CreateBatchUseCase enforces dueDay between 1 and 28', () async {
      // Due day 0 should fail
      final resLow = await createBatchUseCase(
        sessionId: 1,
        courseId: 1,
        name: 'Morning-A',
        monthlyFee: const Money(300000),
        dueDay: 0,
        createdBy: 1,
      );
      expect(resLow.isFailure, true);
      expect(resLow.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<ValidationFailure>());

      // Due day 29 should fail
      final resHigh = await createBatchUseCase(
        sessionId: 1,
        courseId: 1,
        name: 'Morning-A',
        monthlyFee: const Money(300000),
        dueDay: 29,
        createdBy: 1,
      );
      expect(resHigh.isFailure, true);

      // Due day 1 and 28 should succeed
      final resValid1 = await createBatchUseCase(
        sessionId: 1,
        courseId: 1,
        name: 'Morning-A',
        monthlyFee: const Money(300000),
        dueDay: 1,
        createdBy: 1,
      );
      expect(resValid1.isSuccess, true);

      final resValid28 = await createBatchUseCase(
        sessionId: 1,
        courseId: 1,
        name: 'Morning-A',
        monthlyFee: const Money(300000),
        dueDay: 28,
        createdBy: 1,
      );
      expect(resValid28.isSuccess, true);
    });

    test('CreateBatchUseCase rejects negative monthly fees', () async {
      final res = await createBatchUseCase(
        sessionId: 1,
        courseId: 1,
        name: 'Evening-B',
        monthlyFee: const Money(-500),
        dueDay: 10,
        createdBy: 1,
      );
      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('cannot be negative'));
    });

    test('CreateSessionUseCase rejects invalid date range', () async {
      final now = DateTime.now();
      final res = await createSessionUseCase(
        name: '2026-2027',
        startDate: now,
        endDate: now.subtract(const Duration(days: 10)),
        createdBy: 1,
      );
      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('End date must be after'));
    });

    test('CreateCourseUseCase requires non-empty name', () async {
      final res = await createCourseUseCase(
        name: '   ',
        createdBy: 1,
      );
      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<ValidationFailure>());
    });
  });
}
