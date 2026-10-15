/// Abstract repository interface for Academics.
library;

import '../../../../core/errors/failures.dart';
import '../entities/academic_entities.dart';

abstract interface class AcademicRepository {
  // Sessions
  Future<Result<List<AcademicSession>>> getSessions();
  Future<Result<AcademicSession>> createSession({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    required int createdBy,
  });
  Future<Result<void>> setCurrentSession(int sessionId);

  // Courses
  Future<Result<List<Course>>> getCourses();
  Future<Result<Course>> createCourse({
    required String name,
    String? code,
    String? description,
    required int createdBy,
  });

  // Batches
  Future<Result<List<Batch>>> getBatches({int? sessionId, int? courseId});
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
  });
  Future<Result<void>> updateBatchStatus({required int batchId, required bool isActive});
  Future<Result<void>> deleteBatch(int batchId);
  Future<Result<void>> deleteCourse(int courseId);
}
