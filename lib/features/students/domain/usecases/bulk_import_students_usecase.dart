/// Bulk student import use case with Excel formula injection sanitization.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/validators.dart';
import '../entities/student_entities.dart';
import '../repositories/student_repository.dart';

class BulkImportStudentsUseCase {
  const BulkImportStudentsUseCase(this._repository);
  final StudentRepository _repository;

  /// Validates and sanitizes imported student rows before database ingestion.
  /// Protects against formula injection in spreadsheets (prefixes =, +, -, @).
  Future<Result<int>> call({
    required List<StudentImportRow> rawRows,
    required int batchId,
    required int createdBy,
  }) async {
    if (rawRows.isEmpty) {
      return const Failure(ValidationFailure('Import list is empty.'));
    }

    final seenPhones = <String>{};
    final sanitizedRows = <StudentImportRow>[];

    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final cleanName = sanitizeExcelCell(row.name.trim());
      final cleanGuardianPhone = sanitizeExcelCell(row.guardianPhone.trim());
      final cleanPhone = row.phone != null ? sanitizeExcelCell(row.phone!.trim()) : null;
      final cleanEmail = row.email != null ? sanitizeExcelCell(row.email!.trim().toLowerCase()) : null;
      final cleanRoll = row.rollNumber != null ? sanitizeExcelCell(row.rollNumber!.trim()) : null;

      if (cleanName.isEmpty) {
        return Failure(ValidationFailure('Row ${i + 1}: Name cannot be empty.'));
      }
      if (cleanGuardianPhone.isEmpty) {
        return Failure(ValidationFailure('Row ${i + 1}: Guardian phone cannot be empty.'));
      }

      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        if (seenPhones.contains(cleanPhone)) {
          return Failure(ValidationFailure('Row ${i + 1}: Duplicate student phone ($cleanPhone) detected.'));
        }
        seenPhones.add(cleanPhone);
      }

      sanitizedRows.add(StudentImportRow(
        name: cleanName,
        guardianPhone: cleanGuardianPhone,
        phone: cleanPhone?.isEmpty ?? true ? null : cleanPhone,
        email: cleanEmail?.isEmpty ?? true ? null : cleanEmail,
        rollNumber: cleanRoll?.isEmpty ?? true ? null : cleanRoll,
      ));
    }

    return _repository.bulkImportStudents(
      rows: sanitizedRows,
      batchId: batchId,
      createdBy: createdBy,
    );
  }
}
