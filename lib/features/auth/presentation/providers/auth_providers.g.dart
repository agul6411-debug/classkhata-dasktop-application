// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authDaoHash() => r'ad8b2c494b86c03028e12980b4f6edd618b46bf9';

/// See also [authDao].
@ProviderFor(authDao)
final authDaoProvider = AutoDisposeProvider<AuthDao>.internal(
  authDao,
  name: r'authDaoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthDaoRef = AutoDisposeProviderRef<AuthDao>;
String _$authRepositoryHash() => r'8ff8ac59687b7343a74c3e4dabe66ef392a7a2c8';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$loginUseCaseHash() => r'e082833fd1fc26be8c5fac08d612713cb2c18a17';

/// See also [loginUseCase].
@ProviderFor(loginUseCase)
final loginUseCaseProvider = AutoDisposeProvider<LoginUseCase>.internal(
  loginUseCase,
  name: r'loginUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loginUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoginUseCaseRef = AutoDisposeProviderRef<LoginUseCase>;
String _$authSessionNotifierHash() =>
    r'c07be54e1e10b736da55d23f9203e9850a53067a';

/// The currently authenticated user, or null if not logged in.
///
/// Copied from [AuthSessionNotifier].
@ProviderFor(AuthSessionNotifier)
final authSessionNotifierProvider =
    NotifierProvider<AuthSessionNotifier, AuthUser?>.internal(
      AuthSessionNotifier.new,
      name: r'authSessionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authSessionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthSessionNotifier = Notifier<AuthUser?>;
String _$autoLockNotifierHash() => r'0ae5702006df989eed854095e98aa375936d51c2';

/// Whether the session is currently auto-locked.
///
/// Copied from [AutoLockNotifier].
@ProviderFor(AutoLockNotifier)
final autoLockNotifierProvider =
    NotifierProvider<AutoLockNotifier, bool>.internal(
      AutoLockNotifier.new,
      name: r'autoLockNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$autoLockNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AutoLockNotifier = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
