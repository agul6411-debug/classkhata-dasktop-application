/// Academics DAO — database operations for sessions, courses, and batches.
///
/// Uses direct table access on [AppDatabase] without @DriftAccessor.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class AcademicDao {
  const AcademicDao(this._db);
  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<List<AcademicSessionsTableData>> getAllSessions() =>
      (_db.select(_db.academicSessionsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
          .get();

  Future<int> insertSession(AcademicSessionsTableCompanion companion) =>
      _db.into(_db.academicSessionsTable).insert(companion);

  Future<void> setCurrentSession(int sessionId) async {
    await _db.transaction(() async {
      // Set all to false first
      await _db.update(_db.academicSessionsTable).write(
            const AcademicSessionsTableCompanion(isCurrent: Value(false)),
          );
      // Set the specific one to true
      await (_db.update(_db.academicSessionsTable)
            ..where((t) => t.id.equals(sessionId)))
          .write(
            const AcademicSessionsTableCompanion(isCurrent: Value(true)),
          );
    });
  }

  // ---------------------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------------------

  Future<List<CoursesTableData>> getAllCourses() =>
      (_db.select(_db.coursesTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertCourse(CoursesTableCompanion companion) =>
      _db.into(_db.coursesTable).insert(companion);

  // ---------------------------------------------------------------------------
  // Batches
  // ---------------------------------------------------------------------------

  Future<List<BatchesTableData>> getBatches({int? sessionId, int? courseId}) {
    final query = _db.select(_db.batchesTable);
    if (sessionId != null) {
      query.where((t) => t.sessionId.equals(sessionId));
    }
    if (courseId != null) {
      query.where((t) => t.courseId.equals(courseId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<int> insertBatch(BatchesTableCompanion companion) =>
      _db.into(_db.batchesTable).insert(companion);

  Future<int> updateBatchStatus(int batchId, bool isActive) =>
      (_db.update(_db.batchesTable)..where((t) => t.id.equals(batchId))).write(
        BatchesTableCompanion(isActive: Value(isActive)),
      );

  Future<int> getStudentCountInBatch(int batchId) async {
    final students = await (_db.select(_db.studentsTable)..where((t) => t.batchId.equals(batchId))).get();
    return students.length;
  }

  Future<int> deleteBatch(int batchId) =>
      (_db.delete(_db.batchesTable)..where((t) => t.id.equals(batchId))).go();

  Future<int> deleteCourse(int courseId) =>
      (_db.delete(_db.coursesTable)..where((t) => t.id.equals(courseId))).go();
}
