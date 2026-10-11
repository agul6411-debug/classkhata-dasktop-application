/// Use case to register a single student.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/validators.dart';
import '../entities/student_entities.dart';
import '../repositories/student_repository.dart';

class RegisterStudentUseCase {
  final StudentRepository _repository;
  const RegisterStudentUseCase(this._repository);

  Future<Result<Student>> call({
    required String name,
    required int batchId,
    required String guardianPhone,
    String? phone,
    String? email,
    int? familyId,
    String? customRollNumber,
    required int createdBy,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const Failure(ValidationFailure('Student name is required.'));
    }

    final cleanGuardianPhone = guardianPhone.trim();
    if (cleanGuardianPhone.isEmpty) {
      return const Failure(ValidationFailure('Guardian phone number is required.'));
    }

    if (email != null && email.trim().isNotEmpty) {
      if (!isValidEmail(email.trim())) {
        return const Failure(ValidationFailure('Invalid email address format.'));
      }
    }

    return _repository.registerStudent(
      name: cleanName,
      batchId: batchId,
      guardianPhone: cleanGuardianPhone,
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      email: email?.trim().isEmpty ?? true ? null : email!.trim().toLowerCase(),
      familyId: familyId,
      customRollNumber: customRollNumber?.trim().isEmpty ?? true ? null : customRollNumber!.trim(),
      createdBy: createdBy,
    );
  }
}
