import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/features/students/domain/entities/student_entities.dart';
import 'package:classkhata/features/students/domain/repositories/student_repository.dart';
import 'package:classkhata/features/students/domain/usecases/register_student_usecase.dart';
import 'package:classkhata/features/students/domain/usecases/student_management_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class MockStudentRepository implements StudentRepository {
  final List<Student> students = [];

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
    final student = Student(
      id: students.length + 1,
      rollNumber: customRollNumber ?? 'STD-0001',
      batchId: batchId,
      name: name,
      guardianPhone: guardianPhone,
      phone: phone,
      email: email,
      familyId: familyId,
      joiningDate: DateTime.now(),
      status: StudentStatus.active,
    );
    students.add(student);
    return Success(student);
  }

  @override
  Future<Result<List<Student>>> getStudents({int? batchId, String? query, StudentStatus? status}) async {
    return Success(students);
  }

  @override
  Future<Result<Student?>> getStudentById(int id) async => const Success(null);

  @override
  Future<Result<int>> promoteStudents({required List<int> studentIds, required int targetBatchId}) async {
    return Success(studentIds.length);
  }

  @override
  Future<Result<int>> bulkImportStudents({
    required List<StudentImportRow> rows,
    required int batchId,
    required int createdBy,
  }) async {
    return Success(rows.length);
  }

  @override
  Future<Result<void>> updateStudentStatus({required int studentId, required StudentStatus status}) async =>
      const Success(null);

  @override
  Future<Result<List<Family>>> getFamilies() async => const Success([]);

  @override
  Future<Result<Family>> createFamily({
    required String guardianName,
    required String guardianPhone,
    String? address,
    required int createdBy,
  }) async {
    return Success(Family(
      id: 1,
      familyCode: 'FAM-0001',
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      address: address,
    ));
  }
}

void main() {
  late MockStudentRepository repo;
  late RegisterStudentUseCase registerUseCase;
  late PromoteStudentsUseCase promoteUseCase;

  setUp(() {
    repo = MockStudentRepository();
    registerUseCase = RegisterStudentUseCase(repo);
    promoteUseCase = PromoteStudentsUseCase(repo);
  });

  group('Student Use Cases', () {
    test('RegisterStudentUseCase requires valid name and guardian phone', () async {
      final resEmptyName = await registerUseCase(
        name: '   ',
        batchId: 1,
        guardianPhone: '03001234567',
        createdBy: 1,
      );
      expect(resEmptyName.isFailure, true);
      expect(resEmptyName.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<ValidationFailure>());

      final resEmptyPhone = await registerUseCase(
        name: 'Hamza',
        batchId: 1,
        guardianPhone: '  ',
        createdBy: 1,
      );
      expect(resEmptyPhone.isFailure, true);
    });

    test('RegisterStudentUseCase validates email format', () async {
      final resBadEmail = await registerUseCase(
        name: 'Hamza',
        batchId: 1,
        guardianPhone: '03001234567',
        email: 'invalid-email-address',
        createdBy: 1,
      );
      expect(resBadEmail.isFailure, true);
      expect(resBadEmail.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('Invalid email'));

      final resGoodEmail = await registerUseCase(
        name: 'Hamza',
        batchId: 1,
        guardianPhone: '03001234567',
        email: 'hamza@example.com',
        createdBy: 1,
      );
      expect(resGoodEmail.isSuccess, true);
    });

    test('PromoteStudentsUseCase rejects empty student list', () async {
      final res = await promoteUseCase(
        studentIds: [],
        targetBatchId: 2,
      );
      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('No students selected'));
    });
  });
}
