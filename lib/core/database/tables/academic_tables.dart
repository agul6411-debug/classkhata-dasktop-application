/// Academic and Student table definitions for Drift.
///
/// Rules:
///   - Money is stored as INTEGER (paisa).
///   - Batches have due_day restricted between 1 and 28.
///   - Append-only or status-based soft states (active, inactive, left).
library;

import 'package:drift/drift.dart';
import 'core_tables.dart';

// ---------------------------------------------------------------------------
// Academic Sessions
// ---------------------------------------------------------------------------

class AcademicSessionsTable extends Table {
  @override
  String get tableName => 'academic_sessions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g. "2026-2027"
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Courses / Classes
// ---------------------------------------------------------------------------

class CoursesTable extends Table {
  @override
  String get tableName => 'courses';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)(); // e.g. "Matric Science", "English Spoken"
  TextColumn get code => text().withLength(min: 1, max: 50).nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Batches / Sections
// ---------------------------------------------------------------------------

class BatchesTable extends Table {
  @override
  String get tableName => 'batches';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(AcademicSessionsTable, #id)();
  IntColumn get courseId => integer().references(CoursesTable, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g. "Morning-A"
  TextColumn get instructorName => text().nullable()();
  TextColumn get timing => text().nullable()(); // e.g. "09:00 AM - 11:00 AM"
  TextColumn get duration => text().nullable()(); // e.g. "6 Months"
  
  /// Stored as integer paisa (e.g. 500000 = Rs. 5,000.00). Never double!
  IntColumn get monthlyFeePaisa => integer().withDefault(const Constant(0))();
  
  /// Day of the month fee is due (must be 1-28)
  IntColumn get dueDay => integer().withDefault(const Constant(10))();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Families (Sibling / Guardian grouping)
// ---------------------------------------------------------------------------

class FamiliesTable extends Table {
  @override
  String get tableName => 'families';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get familyCode => text().unique()(); // e.g. "FAM-0001"
  TextColumn get guardianName => text().withLength(min: 1, max: 120)();
  TextColumn get guardianPhone => text().withLength(min: 1, max: 50)();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Students
// ---------------------------------------------------------------------------

class StudentsTable extends Table {
  @override
  String get tableName => 'students';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get rollNumber => text().unique()(); // e.g. "STD-0001"
  IntColumn get familyId => integer().nullable().references(FamiliesTable, #id)();
  IntColumn get batchId => integer().references(BatchesTable, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable()();
  TextColumn get guardianPhone => text()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get joiningDate => dateTime().withDefault(currentDateAndTime)();
  
  /// Status: 'active', 'inactive', 'left'
  TextColumn get status => text().withDefault(const Constant('active'))();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}
