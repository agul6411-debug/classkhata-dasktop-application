import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/students/data/datasources/student_dao.dart';
import 'package:classkhata/features/students/data/repositories/student_repository_impl.dart';
import 'package:classkhata/features/students/domain/entities/student_entities.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StudentDao dao;
  late StudentRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = StudentDao(db);
    repository = StudentRepositoryImpl(dao);

    // Seed session, course, batches
    await db.into(db.academicSessionsTable).insert(
          AcademicSessionsTableCompanion.insert(
            name: '2026-2027',
            startDate: DateTime(2026),
            endDate: DateTime(2026, 12, 31),
          ),
        );
    await db.into(db.coursesTable).insert(
          CoursesTableCompanion.insert(name: 'Class 9th'),
        );
    await db.into(db.coursesTable).insert(
          CoursesTableCompanion.insert(name: 'Class 10th'),
        );
    await db.into(db.batchesTable).insert(
          BatchesTableCompanion.insert(
            sessionId: 1,
            courseId: 1,
            name: 'Section A - 9th',
            monthlyFeePaisa: const Value(500000),
            dueDay: const Value(10),
          ),
        );
    await db.into(db.batchesTable).insert(
          BatchesTableCompanion.insert(
            sessionId: 1,
            courseId: 2,
            name: 'Section A - 10th',
            monthlyFeePaisa: const Value(600000),
            dueDay: const Value(10),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Student Queries, Search & Filtering', () {
    test('filters students by batch, status, and query term', () async {
      // Register 3 test students
      await repository.registerStudent(
        name: 'Ayesha Khan',
        batchId: 1,
        guardianPhone: '03001111111',
        phone: '03211111111',
        createdBy: 1,
      );

      await repository.registerStudent(
        name: 'Bilal Ahmed',
        batchId: 1,
        guardianPhone: '03002222222',
        phone: '03212222222',
        createdBy: 1,
      );

      final s3 = await repository.registerStudent(
        name: 'Zainab Fatima',
        batchId: 2,
        guardianPhone: '03003333333',
        createdBy: 1,
      );

      // Deactivate Zainab
      await repository.updateStudentStatus(
        studentId: s3.valueOrThrow.id,
        status: StudentStatus.inactive,
      );

      // 1. Filter by Batch 1
      final batch1Result = await repository.getStudents(batchId: 1);
      expect(batch1Result.isSuccess, isTrue);
      expect(batch1Result.valueOrThrow.length, equals(2));

      // 2. Filter by Status Active
      final activeResult = await repository.getStudents(status: StudentStatus.active);
      expect(activeResult.isSuccess, isTrue);
      expect(activeResult.valueOrThrow.length, equals(2));

      // 3. Filter by Status Inactive
      final inactiveResult = await repository.getStudents(status: StudentStatus.inactive);
      expect(inactiveResult.isSuccess, isTrue);
      expect(inactiveResult.valueOrThrow.length, equals(1));
      expect(inactiveResult.valueOrThrow.first.name, equals('Zainab Fatima'));

      // 4. Search by Name
      final nameSearch = await repository.getStudents(query: 'Bilal');
      expect(nameSearch.isSuccess, isTrue);
      expect(nameSearch.valueOrThrow.length, equals(1));
      expect(nameSearch.valueOrThrow.first.name, equals('Bilal Ahmed'));

      // 5. Search by Guardian Phone
      final phoneSearch = await repository.getStudents(query: '03001111111');
      expect(phoneSearch.isSuccess, isTrue);
      expect(phoneSearch.valueOrThrow.length, equals(1));
      expect(phoneSearch.valueOrThrow.first.name, equals('Ayesha Khan'));
    });

    test('promotes selected students to next batch atomically', () async {
      final s1 = await repository.registerStudent(
        name: 'Student One',
        batchId: 1,
        guardianPhone: '03001111111',
        createdBy: 1,
      );
      final s2 = await repository.registerStudent(
        name: 'Student Two',
        batchId: 1,
        guardianPhone: '03002222222',
        createdBy: 1,
      );

      final id1 = s1.valueOrThrow.id;
      final id2 = s2.valueOrThrow.id;

      // Promote both students from Batch 1 (9th) to Batch 2 (10th)
      final promoteRes = await repository.promoteStudents(
        studentIds: [id1, id2],
        targetBatchId: 2,
      );
      expect(promoteRes.isSuccess, isTrue);
      expect(promoteRes.valueOrThrow, equals(2));

      // Verify batchId is updated
      final updatedStudents = await repository.getStudents(batchId: 2);
      expect(updatedStudents.valueOrThrow.length, equals(2));

      final batch1Students = await repository.getStudents(batchId: 1);
      expect(batch1Students.valueOrThrow.isEmpty, isTrue);
    });

    test('generates sequential gap-free numeric roll numbers (1, 2)', () async {
      final s1 = await repository.registerStudent(
        name: 'Student A',
        batchId: 1,
        guardianPhone: '03001111111',
        createdBy: 1,
      );
      final s2 = await repository.registerStudent(
        name: 'Student B',
        batchId: 1,
        guardianPhone: '03002222222',
        createdBy: 1,
      );

      expect(s1.valueOrThrow.rollNumber, equals('1'));
      expect(s2.valueOrThrow.rollNumber, equals('2'));
    });
  });
}
