/// Service to store and retrieve rich staff profile metadata (photo, father info,
/// qualifications, specialization, etc.) and School Employment Terms using ClassKhata's SettingsTable.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../entities/staff_profile.dart';

class StaffProfileService {
  StaffProfileService._();

  static const String schoolTermsKey = 'school_staff_terms_and_conditions';
  static String _metaKey(int staffId) => 'staff_meta_$staffId';

  /// Default employment terms and code of conduct for schools in Pakistan.
  static const String defaultTerms = '''
1. APPOINTMENT & PROBATION:
The employee is appointed on a probation period of three (3) months. Upon satisfactory pedagogical performance and conduct, employment may be confirmed in writing.

2. SECURITY DEPOSIT / 1-MONTH SALARY POLICY:
As per standard institutional policy, one (1) month salary is held as a security deposit (either deposited upon appointment or retained in initial salary installments). This deposit is fully refundable upon completion of the academic session and clearance of the mandatory one-month resignation notice.

3. DUTY HOURS & PUNCTUALITY:
School working hours must be strictly observed. Staff must arrive at least 15 minutes prior to the morning assembly. Habitual late arrival without prior sanctioned leave may result in proportionate salary deduction.

4. LESSON PLANNING & ACADEMIC DIARIES:
The teacher is responsible for preparing daily lesson plans, maintaining students' academic progress records, checking classwork/homework regularly, and completing syllabus targets on schedule.

5. CODE OF CONDUCT & STUDENT WELFARE:
Corporal punishment, harsh verbal reprimands, physical intimidation, or discriminatory behavior towards students is strictly prohibited by law and school policy. Violations will lead to immediate disciplinary termination.

6. PRIVATE TUITIONS:
Offering private home or commercial tuitions to current students of this school is strictly prohibited without prior written consent from the Principal / Management.

7. LEAVE POLICY & ABSENTEEISM:
Employees are entitled to 1 casual leave per month with prior written approval. Uninformed or unapproved absence will be marked as Leave Without Pay (LWP). Absence during examination periods is strictly prohibited.

8. NOTICE PERIOD FOR RESIGNATION:
Either party may terminate this employment by serving one (1) month prior written notice, or payment of one month salary in lieu thereof. Resignations will not be accepted during ongoing examination or admission sessions.

9. PROFESSIONAL DRESS CODE:
All faculty and administrative members are expected to maintain an exemplary professional dress code, modesty, and decorum reflecting the dignity of an educational institution.
''';

  /// Saves or updates the extended staff profile in the database settings table.
  static Future<void> saveProfile({
    required AppDatabase db,
    required int staffId,
    required StaffProfile profile,
  }) async {
    final key = _metaKey(staffId);
    final jsonStr = profile.toRawJson();
    await db.into(db.settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion(
            key: Value(key),
            value: Value(jsonStr),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Loads the extended staff profile.
  static Future<StaffProfile> getProfile({
    required AppDatabase db,
    required int staffId,
  }) async {
    final key = _metaKey(staffId);
    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return const StaffProfile();
    return StaffProfile.fromRawJson(row.value);
  }

  /// Copies a user-picked photo to local Documents/ClassKhata/StaffPhotos directory.
  static Future<String> persistPhoto(String originalPath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(docDir.path, 'ClassKhata', 'StaffPhotos'));
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    final ext = p.extension(originalPath);
    final fileName = 'staff_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(photoDir.path, fileName);
    final copiedFile = await File(originalPath).copy(targetPath);
    return copiedFile.path;
  }

  /// Loads the school terms and conditions. If not set, returns [defaultTerms].
  static Future<String> getSchoolTerms(AppDatabase db) async {
    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals(schoolTermsKey))).getSingleOrNull();
    if (row == null || row.value.trim().isEmpty) {
      return defaultTerms;
    }
    return row.value;
  }

  /// Saves the customized school terms and conditions.
  static Future<void> saveSchoolTerms({
    required AppDatabase db,
    required String terms,
  }) async {
    await db.into(db.settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion(
            key: const Value(schoolTermsKey),
            value: Value(terms.trim()),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
