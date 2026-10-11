/// Riverpod providers for the setup feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/setup_dao.dart';
import '../../data/repositories/setup_repository_impl.dart';
import '../../domain/repositories/setup_repository.dart';
import '../../domain/usecases/setup_usecases.dart';

part 'setup_providers.g.dart';

@riverpod
SetupDao setupDao(Ref ref) => SetupDao(ref.watch(appDatabaseProvider));

@riverpod
SetupRepository setupRepository(Ref ref) =>
    SetupRepositoryImpl(ref.watch(setupDaoProvider));

@riverpod
RunSetupUseCase runSetupUseCase(Ref ref) =>
    RunSetupUseCase(ref.watch(setupRepositoryProvider));

@riverpod
CheckSetupUseCase checkSetupUseCase(Ref ref) =>
    CheckSetupUseCase(ref.watch(setupRepositoryProvider));
