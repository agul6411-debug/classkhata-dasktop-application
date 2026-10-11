/// Use cases for student search and student promotions.
library;

import '../../../../core/errors/failures.dart';
import '../entities/student_entities.dart';
import '../repositories/student_repository.dart';

class SearchStudentsUseCase {
  final StudentRepository _repository;
  const SearchStudentsUseCase(this._repository);

  Future<Result<List<Student>>> call({
    int? batchId,
    String? query,
    StudentStatus? status,
  }) {
    return _repository.getStudents(
      batchId: batchId,
      query: query?.trim().isEmpty ?? true ? null : query!.trim(),
      status: status,
    );
  }
}

class PromoteStudentsUseCase {
  final StudentRepository _repository;
  const PromoteStudentsUseCase(this._repository);

  Future<Result<int>> call({
    required List<int> studentIds,
    required int targetBatchId,
  }) async {
    if (studentIds.isEmpty) {
      return const Failure(ValidationFailure('No students selected for promotion.'));
    }
    return _repository.promoteStudents(
      studentIds: studentIds,
      targetBatchId: targetBatchId,
    );
  }
}
