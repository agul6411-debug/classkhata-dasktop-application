/// Licensing use cases.
library;

import '../../../../core/errors/failures.dart';
import '../entities/license_entities.dart';
import '../repositories/licensing_repository.dart';

class GetLicenseStatusUseCase {
  const GetLicenseStatusUseCase(this._repository);
  final LicensingRepository _repository;

  Future<Result<LicenseInfo>> call({DateTime? overrideNow}) =>
      _repository.getLicenseInfo(overrideNow: overrideNow);
}

class ActivateLicenseUseCase {
  const ActivateLicenseUseCase(this._repository);
  final LicensingRepository _repository;

  Future<Result<LicenseInfo>> call(String licenseKey) =>
      _repository.activateLicense(licenseKey);
}

class VerifyFinancialActionAllowedUseCase {
  const VerifyFinancialActionAllowedUseCase(this._repository);
  final LicensingRepository _repository;

  Future<Result<bool>> call() async {
    final infoRes = await _repository.getLicenseInfo();
    return infoRes.fold(
      onSuccess: (info) {
        if (info.canPerformFinancialWrites) {
          return const Success(true);
        } else {
          return Failure(
            LicenseExpiredFailure(
              info.alertMessage ?? 'System is in Read-Only mode due to trial expiration or license issue.',
            ),
          );
        }
      },
      onFailure: (f) => Failure(f),
    );
  }
}
