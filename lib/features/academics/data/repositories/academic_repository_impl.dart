/// Academic repository implementation.
library;

import 'package:drift/drift.dart' hide Batch;
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/academic_entities.dart';
import '../../domain/repositories/academic_repository.dart';
import '../datasources/academic_dao.dart';

class AcademicRepositoryImpl implements AcademicRepository {
  final AcademicDao _dao;
  const AcademicRepositoryImpl(this._dao);

  @override
  Future<Result<List<AcademicSession>>> getSessions() async {
    try {
      final rows = await _dao.getAllSessions();
      final list = rows.map((r) => AcademicSession(
            id: r.id,
            name: r.name,
            startDate: r.startDate,
            endDate: r.endDate,
            isCurrent: r.isCurrent,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getSessions error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch academic sessions.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<AcademicSession>> createSession({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertSession(
        AcademicSessionsTableCompanion.insert(
          name: name,
          startDate: startDate,
          endDate: endDate,
          isCurrent: Value(isCurrent),
          createdBy: Value(createdBy),
        ),
      );
      if (isCurrent) {
        await _dao.setCurrentSession(id);
      }
      return Success(AcademicSession(
        id: id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createSession error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create academic session.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> setCurrentSession(int sessionId) async {
    try {
      await _dao.setCurrentSession(sessionId);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('setCurrentSession error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not set current session.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Course>>> getCourses() async {
    try {
      final rows = await _dao.getAllCourses();
      final list = rows.map((r) => Course(
            id: r.id,
            name: r.name,
            code: r.code,
            description: r.description,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getCourses error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch courses.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Course>> createCourse({
    required String name,
    String? code,
    String? description,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertCourse(
        CoursesTableCompanion.insert(
          name: name,
          code: Value(code),
          description: Value(description),
          createdBy: Value(createdBy),
        ),
      );
      return Success(Course(
        id: id,
        name: name,
        code: code,
        description: description,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createCourse error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create course.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Batch>>> getBatches({int? sessionId, int? courseId}) async {
    try {
      final rows = await _dao.getBatches(sessionId: sessionId, courseId: courseId);
      final list = rows.map((r) => Batch(
            id: r.id,
            sessionId: r.sessionId,
            courseId: r.courseId,
            name: r.name,
            instructorName: r.instructorName,
            timing: r.timing,
            duration: r.duration,
            monthlyFee: Money.fromPaisa(r.monthlyFeePaisa),
            dueDay: r.dueDay,
            isActive: r.isActive,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getBatches error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch batches.', technicalDetail: e.toString()));
    }
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
    try {
      final id = await _dao.insertBatch(
        BatchesTableCompanion.insert(
          sessionId: sessionId,
          courseId: courseId,
          name: name,
          instructorName: Value(instructorName),
          timing: Value(timing),
          duration: Value(duration),
          monthlyFeePaisa: Value(monthlyFeePaisa),
          dueDay: Value(dueDay),
          createdBy: Value(createdBy),
        ),
      );
      return Success(Batch(
        id: id,
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
    } catch (e, st) {
      await AppLogger.instance.error('createBatch error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create batch.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateBatchStatus({required int batchId, required bool isActive}) async {
    try {
      await _dao.updateBatchStatus(batchId, isActive);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('updateBatchStatus error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not update batch status.', technicalDetail: e.toString()));
    }
  }
}
