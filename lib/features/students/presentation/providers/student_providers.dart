/// Riverpod providers for Student Management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../../app/providers.dart';
import '../../data/datasources/student_dao.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/student_repository.dart';
import '../../domain/services/student_profile_service.dart';
import '../../domain/usecases/bulk_import_students_usecase.dart';
import '../../domain/usecases/register_student_usecase.dart';
import '../../domain/usecases/student_management_usecases.dart';

final studentDaoProvider = Provider<StudentDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StudentDao(db);
});

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final dao = ref.watch(studentDaoProvider);
  return StudentRepositoryImpl(dao);
});

final registerStudentUseCaseProvider = Provider<RegisterStudentUseCase>((ref) {
  return RegisterStudentUseCase(ref.watch(studentRepositoryProvider));
});

final searchStudentsUseCaseProvider = Provider<SearchStudentsUseCase>((ref) {
  return SearchStudentsUseCase(ref.watch(studentRepositoryProvider));
});

final promoteStudentsUseCaseProvider = Provider<PromoteStudentsUseCase>((ref) {
  return PromoteStudentsUseCase(ref.watch(studentRepositoryProvider));
});

final bulkImportStudentsUseCaseProvider = Provider<BulkImportStudentsUseCase>((ref) {
  return BulkImportStudentsUseCase(ref.watch(studentRepositoryProvider));
});

/// Search & Filter criteria for the students list.
class StudentFilterState {

  const StudentFilterState({
    this.batchId,
    this.query = '',
    this.status,
  });
  final int? batchId;
  final String query;
  final StudentStatus? status;

  StudentFilterState copyWith({
    int? Function()? batchId,
    String? query,
    StudentStatus? Function()? status,
  }) {
    return StudentFilterState(
      batchId: batchId != null ? batchId() : this.batchId,
      query: query ?? this.query,
      status: status != null ? status() : this.status,
    );
  }
}

class StudentFilterNotifier extends StateNotifier<StudentFilterState> {
  StudentFilterNotifier() : super(const StudentFilterState());

  void setBatchId(int? batchId) => state = state.copyWith(batchId: () => batchId);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setStatus(StudentStatus? status) => state = state.copyWith(status: () => status);
  void reset() => state = const StudentFilterState();
}

final studentFilterProvider =
    StateNotifierProvider<StudentFilterNotifier, StudentFilterState>((ref) {
  return StudentFilterNotifier();
});

/// Mutation counter to notify dependent providers when students change.
final studentListVersionProvider = StateProvider<int>((ref) => 0);

/// Future provider querying students according to active filters.
final studentsListProvider = FutureProvider<List<Student>>((ref) async {
  final filter = ref.watch(studentFilterProvider);
  final searchUseCase = ref.watch(searchStudentsUseCaseProvider);
  final result = await searchUseCase(
    batchId: filter.batchId,
    query: filter.query,
    status: filter.status,
  );
  return result.fold(
    onSuccess: (students) => students,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Future provider querying family groups.
final familiesListProvider = FutureProvider<List<Family>>((ref) async {
  ref.watch(studentListVersionProvider);
  final repo = ref.watch(studentRepositoryProvider);
  final result = await repo.getFamilies();
  return result.fold(
    onSuccess: (families) => families,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Family students query
final familyStudentsProvider = FutureProvider.family<List<Student>, int>((ref, familyId) async {
  ref.watch(studentListVersionProvider);
  final repo = ref.watch(studentRepositoryProvider);
  final result = await repo.getStudentsByFamilyId(familyId);
  return result.fold(
    onSuccess: (students) => students,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Student Profile provider (fetching photo, father details, fee package)
final studentProfileProvider = FutureProvider.family<StudentProfile, int>((ref, studentId) async {
  ref.watch(studentListVersionProvider);
  final db = ref.watch(appDatabaseProvider);
  return StudentProfileService.getProfile(db: db, studentId: studentId);
});
