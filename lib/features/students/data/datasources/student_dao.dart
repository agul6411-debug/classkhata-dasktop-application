/// Student and Family DAO.
///
/// Direct database operations on [AppDatabase] without @DriftAccessor.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/student_entities.dart';

class StudentDao {
  const StudentDao(this._db);
  final AppDatabase _db;

  AppDatabase get db => _db;

  // ---------------------------------------------------------------------------
  // Students Queries
  // ---------------------------------------------------------------------------

  Future<List<StudentsTableData>> getStudents({
    int? batchId,
    String? query,
    StudentStatus? status,
  }) {
    final selectQuery = _db.select(_db.studentsTable);

    if (batchId != null) {
      selectQuery.where((t) => t.batchId.equals(batchId));
    }

    if (status != null) {
      selectQuery.where((t) => t.status.equals(status.name));
    }

    if (query != null && query.isNotEmpty) {
      final pattern = '%$query%';
      selectQuery.where((t) =>
          t.name.like(pattern) |
          t.rollNumber.like(pattern) |
          t.guardianPhone.like(pattern) |
          t.phone.like(pattern));
    }

    selectQuery.orderBy([(t) => OrderingTerm.asc(t.rollNumber)]);
    return selectQuery.get();
  }

  Future<StudentsTableData?> getStudentById(int id) =>
      (_db.select(_db.studentsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertStudent(StudentsTableCompanion companion) =>
      _db.into(_db.studentsTable).insert(companion);

  Future<int> updateStudent(int studentId, StudentsTableCompanion companion) =>
      (_db.update(_db.studentsTable)..where((t) => t.id.equals(studentId))).write(companion);

  Future<int> deleteStudent(int studentId) =>
      (_db.delete(_db.studentsTable)..where((t) => t.id.equals(studentId))).go();

  Future<List<StudentsTableData>> getStudentsByGuardianPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return (_db.select(_db.studentsTable)
          ..where((t) => t.guardianPhone.equals(phone) | t.guardianPhone.like('%$clean%')))
        .get();
  }

  Future<List<StudentsTableData>> getStudentsByFamilyId(int familyId) =>
      (_db.select(_db.studentsTable)..where((t) => t.familyId.equals(familyId))).get();

  Future<void> updateStudentStatus(int studentId, String status) =>
      (_db.update(_db.studentsTable)..where((t) => t.id.equals(studentId))).write(
        StudentsTableCompanion(status: Value(status)),
      );

  Future<int> promoteStudents(List<int> studentIds, int targetBatchId) async {
    return _db.transaction(() async {
      int count = 0;
      for (final id in studentIds) {
        final updated = await (_db.update(_db.studentsTable)..where((t) => t.id.equals(id))).write(
          StudentsTableCompanion(batchId: Value(targetBatchId)),
        );
        count += updated;
      }
      return count;
    });
  }

  Future<int> bulkInsertStudents(List<StudentsTableCompanion> companions) async {
    return _db.transaction(() async {
      int count = 0;
      for (final companion in companions) {
        await _db.into(_db.studentsTable).insert(companion);
        count++;
      }
      return count;
    });
  }

  /// Generates the next sequential numeric roll number (e.g. 1, 2, 24).
  Future<String> getNextRollNumber() async {
    final students = await _db.select(_db.studentsTable).get();
    int maxRoll = 0;
    for (final s in students) {
      final rollNum = int.tryParse(s.rollNumber.trim());
      if (rollNum != null && rollNum > maxRoll) {
        maxRoll = rollNum;
      }
    }
    return (maxRoll + 1).toString();
  }

  // ---------------------------------------------------------------------------
  // Families
  // ---------------------------------------------------------------------------

  Future<List<FamiliesTableData>> getFamilies() =>
      (_db.select(_db.familiesTable)..orderBy([(t) => OrderingTerm.asc(t.familyCode)])).get();

  Future<int> insertFamily(FamiliesTableCompanion companion) =>
      _db.into(_db.familiesTable).insert(companion);

  Future<String> getNextFamilyCode() async {
    final count = await _db.select(_db.familiesTable).get();
    final nextNumber = count.length + 1;
    return 'FAM-${nextNumber.toString().padLeft(4, '0')}';
  }
}
