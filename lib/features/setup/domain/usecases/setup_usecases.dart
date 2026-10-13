/// Run-setup use case.
library;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../entities/setup_data.dart';
import '../repositories/setup_repository.dart';

/// Validates setup input and delegates to the repository.
class RunSetupUseCase {

  const RunSetupUseCase(this._repository);
  final SetupRepository _repository;

  Future<Result<String>> call(SetupData data) async {
    // Validate academy name
    if (data.academyName.trim().isEmpty) {
      return const Failure(ValidationFailure('Academy name is required.'));
    }
    // Validate admin fields
    if (data.adminName.trim().isEmpty) {
      return const Failure(ValidationFailure('Admin name is required.'));
    }
    if (data.adminEmail.trim().isEmpty) {
      return const Failure(ValidationFailure('Admin email is required.'));
    }
    if (data.adminPassword.length < AppConstants.minPasswordLength) {
      return const Failure(
        ValidationFailure(
          'Password must be at least ${AppConstants.minPasswordLength} characters.',
        ),
      );
    }
    return _repository.runSetup(data);
  }
}

/// Check-setup use case.
class CheckSetupUseCase {

  const CheckSetupUseCase(this._repository);
  final SetupRepository _repository;

  Future<Result<bool>> call() => _repository.isSetupComplete();
}
