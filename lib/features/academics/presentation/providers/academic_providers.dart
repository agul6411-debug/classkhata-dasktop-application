/// Riverpod providers for Academics.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/academic_dao.dart';
import '../../data/repositories/academic_repository_impl.dart';
import '../../domain/entities/academic_entities.dart';
import '../../domain/repositories/academic_repository.dart';
import '../../domain/usecases/academic_usecases.dart';

final academicDaoProvider = Provider<AcademicDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AcademicDao(db);
});

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final dao = ref.watch(academicDaoProvider);
  return AcademicRepositoryImpl(dao);
});

final createSessionUseCaseProvider = Provider<CreateSessionUseCase>((ref) {
  return CreateSessionUseCase(ref.watch(academicRepositoryProvider));
});

final createCourseUseCaseProvider = Provider<CreateCourseUseCase>((ref) {
  return CreateCourseUseCase(ref.watch(academicRepositoryProvider));
});

final createBatchUseCaseProvider = Provider<CreateBatchUseCase>((ref) {
  return CreateBatchUseCase(ref.watch(academicRepositoryProvider));
});

final getAcademicDataUseCaseProvider = Provider<GetAcademicDataUseCase>((ref) {
  return GetAcademicDataUseCase(ref.watch(academicRepositoryProvider));
});

/// Future provider to fetch sessions, courses, and batches.
final academicDataProvider = FutureProvider<({
  List<AcademicSession> sessions,
  List<Course> courses,
  List<Batch> batches,
})>((ref) async {
  final useCase = ref.watch(getAcademicDataUseCaseProvider);
  final result = await useCase();
  return result.fold(
    onSuccess: (data) => data,
    onFailure: (f) => throw Exception(f.message),
  );
});
