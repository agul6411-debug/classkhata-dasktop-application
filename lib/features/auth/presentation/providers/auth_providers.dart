/// Riverpod providers for the auth feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/auth_dao.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';

part 'auth_providers.g.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

@riverpod
AuthDao authDao(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return AuthDao(db);
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(ref.watch(authDaoProvider));
}

@riverpod
LoginUseCase loginUseCase(Ref ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
}

// ---------------------------------------------------------------------------
// Auth session state
// ---------------------------------------------------------------------------

/// The currently authenticated user, or null if not logged in.
@Riverpod(keepAlive: true)
class AuthSessionNotifier extends _$AuthSessionNotifier {
  @override
  AuthUser? build() => null;

  void login(AuthUser user) => state = user;
  void logout() => state = null;
  void updateUser(AuthUser user) => state = user;
}

// ---------------------------------------------------------------------------
// Auto-lock state
// ---------------------------------------------------------------------------

/// Whether the session is currently auto-locked.
@Riverpod(keepAlive: true)
class AutoLockNotifier extends _$AutoLockNotifier {
  @override
  bool build() => false;

  void lock() => state = true;
  void unlock() => state = false;
}
