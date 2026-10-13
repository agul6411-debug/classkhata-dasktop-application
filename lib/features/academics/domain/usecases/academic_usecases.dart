/// Academics domain use cases with validation and business rules.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/academic_entities.dart';
import '../repositories/academic_repository.dart';

class CreateSessionUseCase {
  const CreateSessionUseCase(this._repository);
  final AcademicRepository _repository;

  Future<Result<AcademicSession>> call({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
    required int createdBy,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(ValidationFailure('Session name is required.'));
    }
    if (endDate.isBefore(startDate)) {
      return const Failure(ValidationFailure('End date must be after start date.'));
    }
    return _repository.createSession(
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      createdBy: createdBy,
    );
  }
}

class CreateCourseUseCase {
  const CreateCourseUseCase(this._repository);
  final AcademicRepository _repository;

  Future<Result<Course>> call({
    required String name,
    String? code,
    String? description,
    required int createdBy,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(ValidationFailure('Course name is required.'));
    }
    return _repository.createCourse(
      name: name.trim(),
      code: code?.trim(),
      description: description?.trim(),
      createdBy: createdBy,
    );
  }
}

class CreateBatchUseCase {
  const CreateBatchUseCase(this._repository);
  final AcademicRepository _repository;

  Future<Result<Batch>> call({
    required int sessionId,
    required int courseId,
    required String name,
    String? instructorName,
    String? timing,
    String? duration,
    required Money monthlyFee,
    required int dueDay,
    required int createdBy,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(ValidationFailure('Batch name is required.'));
    }
    if (dueDay < 1 || dueDay > 28) {
      return const Failure(ValidationFailure('Due day must be between 1 and 28.'));
    }
    if (monthlyFee.isNegative) {
      return const Failure(ValidationFailure('Monthly fee cannot be negative.'));
    }
    return _repository.createBatch(
      sessionId: sessionId,
      courseId: courseId,
      name: name.trim(),
      instructorName: instructorName?.trim(),
      timing: timing?.trim(),
      duration: duration?.trim(),
      monthlyFeePaisa: monthlyFee.paisa,
      dueDay: dueDay,
      createdBy: createdBy,
    );
  }
}

class GetAcademicDataUseCase {
  const GetAcademicDataUseCase(this._repository);
  final AcademicRepository _repository;

  Future<Result<({List<AcademicSession> sessions, List<Course> courses, List<Batch> batches})>> call() async {
    final sRes = await _repository.getSessions();
    if (sRes.isFailure) return Failure(sRes.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));

    final cRes = await _repository.getCourses();
    if (cRes.isFailure) return Failure(cRes.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));

    final bRes = await _repository.getBatches();
    if (bRes.isFailure) return Failure(bRes.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));

    return Success((
      sessions: sRes.valueOrThrow,
      courses: cRes.valueOrThrow,
      batches: bRes.valueOrThrow,
    ));
  }
}

class SetCurrentSessionUseCase {
  const SetCurrentSessionUseCase(this._repository);
  final AcademicRepository _repository;

  Future<Result<void>> call(int sessionId) => _repository.setCurrentSession(sessionId);
}

