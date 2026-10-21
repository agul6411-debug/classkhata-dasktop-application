/// Service to store and retrieve rich student profile metadata (photo, father info, fee package)
/// using ClassKhata's SettingsTable storage.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../entities/student_profile.dart';

class StudentProfileService {
  StudentProfileService._();

  static String _metaKey(int studentId) => 'student_meta_$studentId';

  /// Saves or updates the extended student profile in the database settings table.
  static Future<void> saveProfile({
    required AppDatabase db,
    required int studentId,
    required StudentProfile profile,
  }) async {
    final key = _metaKey(studentId);
    final jsonStr = profile.toRawJson();
    await db.into(db.settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion(
            key: Value(key),
            value: Value(jsonStr),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Loads the extended student profile.
  static Future<StudentProfile> getProfile({
    required AppDatabase db,
    required int studentId,
  }) async {
    final key = _metaKey(studentId);
    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return const StudentProfile();
    return StudentProfile.fromRawJson(row.value);
  }

  /// Loads all extended student profiles in a single query.
  static Future<Map<int, StudentProfile>> getAllProfiles(AppDatabase db) async {
    final rows = await (db.select(db.settingsTable)
          ..where((t) => t.key.like('student_meta_%')))
        .get();
    final result = <int, StudentProfile>{};
    for (final row in rows) {
      final idStr = row.key.replaceFirst('student_meta_', '');
      final id = int.tryParse(idStr);
      if (id != null) {
        result[id] = StudentProfile.fromRawJson(row.value);
      }
    }
    return result;
  }

  /// Copies a user-picked photo to local Documents/ClassKhata/StudentPhotos directory.
  static Future<String> persistPhoto(String originalPath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(docDir.path, 'ClassKhata', 'StudentPhotos'));
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    final ext = p.extension(originalPath);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(photoDir.path, fileName);
    final copiedFile = await File(originalPath).copy(targetPath);
    return copiedFile.path;
  }
}
