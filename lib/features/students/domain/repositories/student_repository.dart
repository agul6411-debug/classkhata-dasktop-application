/// Abstract repository for student management.
library;

import '../../../../core/errors/failures.dart';
import '../entities/student_entities.dart';

abstract interface class StudentRepository {
  Future<Result<List<Student>>> getStudents({
    int? batchId,
    String? query,
    StudentStatus? status,
  });

  Future<Result<Student?>> getStudentById(int id);

  Future<Result<Student>> registerStudent({
    required String name,
    required int batchId,
    required String guardianPhone,
    String? phone,
    String? email,
    int? familyId,
    String? customRollNumber,
    required int createdBy,
  });

  Future<Result<void>> updateStudentStatus({
    required int studentId,
    required StudentStatus status,
  });

  Future<Result<int>> promoteStudents({
    required List<int> studentIds,
    required int targetBatchId,
  });

  Future<Result<int>> bulkImportStudents({
    required List<StudentImportRow> rows,
    required int batchId,
    required int createdBy,
  });

  Future<Result<void>> updateStudent({
    required int id,
    required String name,
    required int batchId,
    required String guardianPhone,
    String? phone,
    String? email,
    String? rollNumber,
    int? familyId,
  });

  Future<Result<void>> deleteStudent(int id);

  Future<Result<List<Student>>> getStudentsByGuardianPhone(String phone);

  Future<Result<List<Student>>> getStudentsByFamilyId(int familyId);

  // Families
  Future<Result<List<Family>>> getFamilies();
  Future<Result<Family>> createFamily({
    required String guardianName,
    required String guardianPhone,
    String? address,
    required int createdBy,
  });
}
