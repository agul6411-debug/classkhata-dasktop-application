/// Application-wide failure types and Result type.
library;

import 'package:equatable/equatable.dart';

// ---------------------------------------------------------------------------
// Failure hierarchy
// ---------------------------------------------------------------------------

/// Base class for all application failures.
abstract class AppFailure extends Equatable {
  final String message;
  final String? technicalDetail;

  const AppFailure(this.message, {this.technicalDetail});

  @override
  List<Object?> get props => [message, technicalDetail];
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {super.technicalDetail});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.technicalDetail});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.technicalDetail});
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.technicalDetail});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.technicalDetail});
}

class BackupFailure extends AppFailure {
  const BackupFailure(super.message, {super.technicalDetail});
}

class IntegrityFailure extends AppFailure {
  const IntegrityFailure(super.message, {super.technicalDetail});
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.technicalDetail});
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// A simple Result type that wraps either a success value [T] or an
/// [AppFailure].  Use in domain layer — never throw across layer boundaries.
sealed class Result<T> {
  const Result();

  /// Returns true if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Returns the value or throws a [StateError] if this is a failure.
  T get valueOrThrow => switch (this) {
        Success(:final value) => value,
        Failure(:final failure) =>
          throw StateError('Result is a failure: ${failure.message}'),
      };

  /// Maps the success value, forwarding failures unchanged.
  Result<U> map<U>(U Function(T value) f) => switch (this) {
        Success(:final value) => Success(f(value)),
        Failure(:final failure) => Failure(failure),
      };

  /// Runs [onSuccess] or [onFailure] and returns the result.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final failure) => onFailure(failure),
      };
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}
