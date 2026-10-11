/// Abstract setup repository.
library;

import '../../../../core/errors/failures.dart';
import '../entities/setup_data.dart';

abstract interface class SetupRepository {
  /// Returns true if the app has already been set up (academy + admin exist).
  Future<Result<bool>> isSetupComplete();

  /// Runs the full setup: creates the academy profile, admin user, recovery key.
  /// Returns the one-time recovery key string to show the user.
  Future<Result<String>> runSetup(SetupData data);
}
