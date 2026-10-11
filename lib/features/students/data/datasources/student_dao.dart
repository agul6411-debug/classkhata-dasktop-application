/// Student and Family DAO.
///
/// Direct database operations on [AppDatabase] without @DriftAccessor.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/student_entities.dart';

class StudentDao {
  final AppDatabase _db;
  const StudentDao(this._db);

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

  /// Generates the next roll number (e.g. STD-0001).
  Future<String> getNextRollNumber() async {
    final count = await _db.select(_db.studentsTable).get();
    final nextNumber = count.length + 1;
    return 'STD-${nextNumber.toString().padLeft(4, '0')}';
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
