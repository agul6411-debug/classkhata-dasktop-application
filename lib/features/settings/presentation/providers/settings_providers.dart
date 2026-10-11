/// Riverpod providers for Academy Profile and Application Settings.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../../../core/database/app_database.dart';

final academyProfileProvider = FutureProvider<AcademyProfileTableData?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.academyProfileTable)..limit(1)).getSingleOrNull();
});

final appSettingsMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.select(db.settingsTable).get();
  return {for (var r in rows) r.key: r.value};
});

/// Controller to update settings in the database.
class SettingsController {
  final AppDatabase _db;
  const SettingsController(this._db);

  Future<void> updateSetting(String key, String value) async {
    await _db.into(_db.settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> updateAcademyProfile({
    required String name,
    String? tagline,
    String? phone,
    String? address,
  }) async {
    final existing = await (_db.select(_db.academyProfileTable)..limit(1)).getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.academyProfileTable).insert(
            AcademyProfileTableCompanion.insert(
              name: name,
              tagline: Value(tagline),
              phone: Value(phone),
              address: Value(address),
            ),
          );
    } else {
      await (_db.update(_db.academyProfileTable)..where((t) => t.id.equals(existing.id))).write(
        AcademyProfileTableCompanion(
          name: Value(name),
          tagline: Value(tagline),
          phone: Value(phone),
          address: Value(address),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref.watch(appDatabaseProvider));
});
