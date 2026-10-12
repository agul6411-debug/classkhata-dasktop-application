/// Licensing repository contract.
library;

import '../../../../core/errors/failures.dart';
import '../entities/license_entities.dart';

abstract class LicensingRepository {
  /// Evaluates and retrieves current license status (trial/active/expired/tampered).
  Future<Result<LicenseInfo>> getLicenseInfo({DateTime? overrideNow});

  /// Offline validation and activation of a signed RSA license token.
  Future<Result<LicenseInfo>> activateLicense(String licenseKeyToken);

  /// Heartbeat check ensuring system clock hasn't been rolled back and writes are allowed.
  Future<Result<bool>> canPerformFinancialWrites();
}
