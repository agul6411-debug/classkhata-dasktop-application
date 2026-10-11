/// Student repository implementation.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/repositories/student_repository.dart';
import '../datasources/student_dao.dart';

class StudentRepositoryImpl implements StudentRepository {
  final StudentDao _dao;
  const StudentRepositoryImpl(this._dao);

  @override
  Future<Result<List<Student>>> getStudents({
    int? batchId,
    String? query,
    StudentStatus? status,
  }) async {
    try {
      final rows = await _dao.getStudents(
        batchId: batchId,
        query: query,
        status: status,
      );
      final list = rows.map(_mapStudentRow).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getStudents error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch students.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Student?>> getStudentById(int id) async {
    try {
      final row = await _dao.getStudentById(id);
      return Success(row != null ? _mapStudentRow(row) : null);
    } catch (e, st) {
      await AppLogger.instance.error('getStudentById error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch student.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Student>> registerStudent({
    required String name,
    required int batchId,
    required String guardianPhone,
    String? phone,
    String? email,
    int? familyId,
    String? customRollNumber,
    required int createdBy,
  }) async {
    try {
      final rollNumber = customRollNumber ?? await _dao.getNextRollNumber();
      final id = await _dao.insertStudent(
        StudentsTableCompanion.insert(
          rollNumber: rollNumber,
          batchId: batchId,
          name: name,
          guardianPhone: guardianPhone,
          phone: Value(phone),
          email: Value(email),
          familyId: Value(familyId),
          createdBy: Value(createdBy),
        ),
      );

      final student = Student(
        id: id,
        rollNumber: rollNumber,
        familyId: familyId,
        batchId: batchId,
        name: name,
        phone: phone,
        guardianPhone: guardianPhone,
        email: email,
        joiningDate: DateTime.now(),
        status: StudentStatus.active,
      );
      return Success(student);
    } catch (e, st) {
      await AppLogger.instance.error('registerStudent error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not register student.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateStudentStatus({
    required int studentId,
    required StudentStatus status,
  }) async {
    try {
      await _dao.updateStudentStatus(studentId, status.name);
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('updateStudentStatus error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not update student status.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<int>> promoteStudents({
    required List<int> studentIds,
    required int targetBatchId,
  }) async {
    try {
      final count = await _dao.promoteStudents(studentIds, targetBatchId);
      return Success(count);
    } catch (e, st) {
      await AppLogger.instance.error('promoteStudents error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not promote students.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<int>> bulkImportStudents({
    required List<StudentImportRow> rows,
    required int batchId,
    required int createdBy,
  }) async {
    try {
      final companions = <StudentsTableCompanion>[];
      final baseCount = (await _dao.db.select(_dao.db.studentsTable).get()).length;

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final rollNumber = row.rollNumber ?? 'STD-${(baseCount + i + 1).toString().padLeft(4, '0')}';
        companions.add(StudentsTableCompanion.insert(
          rollNumber: rollNumber,
          batchId: batchId,
          name: row.name,
          guardianPhone: row.guardianPhone,
          phone: Value(row.phone),
          email: Value(row.email),
          createdBy: Value(createdBy),
        ));
      }

      final count = await _dao.bulkInsertStudents(companions);
      return Success(count);
    } catch (e, st) {
      await AppLogger.instance.error('bulkImportStudents error', error: e, stack: st);
      return Failure(DatabaseFailure('Bulk student import failed.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Family>>> getFamilies() async {
    try {
      final rows = await _dao.getFamilies();
      final list = rows.map((r) => Family(
            id: r.id,
            familyCode: r.familyCode,
            guardianName: r.guardianName,
            guardianPhone: r.guardianPhone,
            address: r.address,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getFamilies error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch families.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Family>> createFamily({
    required String guardianName,
    required String guardianPhone,
    String? address,
    required int createdBy,
  }) async {
    try {
      final code = await _dao.getNextFamilyCode();
      final id = await _dao.insertFamily(
        FamiliesTableCompanion.insert(
          familyCode: code,
          guardianName: guardianName,
          guardianPhone: guardianPhone,
          address: Value(address),
          createdBy: Value(createdBy),
        ),
      );
      return Success(Family(
        id: id,
        familyCode: code,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
        address: address,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createFamily error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create family.', technicalDetail: e.toString()));
    }
  }

  Student _mapStudentRow(StudentsTableData r) {
    return Student(
      id: r.id,
      rollNumber: r.rollNumber,
      familyId: r.familyId,
      batchId: r.batchId,
      name: r.name,
      phone: r.phone,
      guardianPhone: r.guardianPhone,
      email: r.email,
      joiningDate: r.joiningDate,
      status: StudentStatus.fromString(r.status),
    );
  }
}
