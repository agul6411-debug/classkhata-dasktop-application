import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/utils/validators.dart';
import 'package:classkhata/features/students/domain/entities/student_entities.dart';
import 'package:classkhata/features/students/domain/usecases/bulk_import_students_usecase.dart';
import 'student_usecases_test.dart';

void main() {
  group('Excel Sanitization & Bulk Import', () {
    test('sanitizeExcelCell prefixes dangerous characters (=, +, -, @) with single quote', () {
      expect(sanitizeExcelCell('=SUM(A1:A10)'), "'=SUM(A1:A10)");
      expect(sanitizeExcelCell('+cmd|/c calc'), "'+cmd|/c calc");
      expect(sanitizeExcelCell('-2+3*10'), "'-2+3*10");
      expect(sanitizeExcelCell('@admin'), "'@admin");

      // Safe cells remain untouched
      expect(sanitizeExcelCell('Ali Khan'), 'Ali Khan');
      expect(sanitizeExcelCell('03001234567'), '03001234567');
      expect(sanitizeExcelCell(''), '');
    });

    test('BulkImportStudentsUseCase sanitizes rows before repository ingestion', () async {
      final repo = MockStudentRepository();
      final useCase = BulkImportStudentsUseCase(repo);

      final dirtyRows = [
        const StudentImportRow(
          name: '=cmd|/c calc!A0',
          guardianPhone: '+923001234567',
          email: '-test@malicious.com',
        ),
        const StudentImportRow(
          name: '@Supervisor',
          guardianPhone: '03009876543',
        ),
      ];

      final res = await useCase(
        rawRows: dirtyRows,
        batchId: 1,
        createdBy: 1,
      );

      expect(res.isSuccess, true);
      expect(res.valueOrThrow, 2);
    });

    test('BulkImportStudentsUseCase rejects rows with empty names', () async {
      final repo = MockStudentRepository();
      final useCase = BulkImportStudentsUseCase(repo);

      final invalidRows = [
        const StudentImportRow(
          name: '   ',
          guardianPhone: '03001234567',
        ),
      ];

      final res = await useCase(
        rawRows: invalidRows,
        batchId: 1,
        createdBy: 1,
      );

      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('Name cannot be empty'));
    });

    test('BulkImportStudentsUseCase detects duplicate student phone in import batch', () async {
      final repo = MockStudentRepository();
      final useCase = BulkImportStudentsUseCase(repo);

      final duplicateRows = [
        const StudentImportRow(
          name: 'Student One',
          guardianPhone: '03001111111',
          phone: '03219999999',
        ),
        const StudentImportRow(
          name: 'Student Two',
          guardianPhone: '03002222222',
          phone: '03219999999',
        ),
      ];

      final res = await useCase(
        rawRows: duplicateRows,
        batchId: 1,
        createdBy: 1,
      );

      expect(res.isFailure, true);
      expect(res.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('Duplicate student phone'));
    });
  });
}
