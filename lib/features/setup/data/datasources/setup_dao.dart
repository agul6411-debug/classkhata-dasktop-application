/// Setup DAO — database operations for the setup wizard.
///
/// Accesses tables directly through [AppDatabase] without @DriftAccessor.
library;

import '../../../../core/database/app_database.dart';

class SetupDao {
  final AppDatabase _db;

  const SetupDao(this._db);

  AppDatabase get db => _db;

  Future<int> getAcademyCount() async {
    final list = await _db.select(_db.academyProfileTable).get();
    return list.length;
  }

  Future<int> insertAcademy(AcademyProfileTableCompanion companion) =>
      _db.into(_db.academyProfileTable).insert(companion);

  Future<int> insertUser(UsersTableCompanion companion) =>
      _db.into(_db.usersTable).insert(companion);

  Future<void> insertRecoveryKey(RecoveryKeysTableCompanion companion) =>
      _db.into(_db.recoveryKeysTable).insert(companion);

  Future<void> insertLicenseState(LicenseStateTableCompanion companion) =>
      _db.into(_db.licenseStateTable).insert(companion);

  Future<AcademyProfileTableData?> getAcademy() =>
      _db.select(_db.academyProfileTable).getSingleOrNull();
}
