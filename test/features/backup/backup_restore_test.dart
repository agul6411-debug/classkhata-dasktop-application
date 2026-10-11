import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:classkhata/core/constants/app_constants.dart';
import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/backup/data/repositories/backup_repository_impl.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late BackupRepositoryImpl backupRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('classkhata_backup_test_');
    dbFile = File(p.join(tempDir.path, AppConstants.dbFileName));
    // Create an initial fake database file with known content
    await dbFile.writeAsString('SQLCipher-Encrypted-Database-Content-V1');

    db = AppDatabase.forTesting(NativeDatabase.memory());
    backupRepo = BackupRepositoryImpl(db, overrideAppDir: tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Encrypted Backup & Restore Round Trip', () {
    test('createBackup creates timestamped snapshot with SHA-256 checksum', () async {
      final result = await backupRepo.createBackup(type: 'manual', createdBy: 1);
      expect(result.isSuccess, isTrue);

      final meta = result.valueOrThrow;
      expect(meta.type, equals('manual'));
      expect(meta.sizeBytes, greaterThan(0));
      expect(meta.checksum, isNotEmpty);
      expect(File(meta.filePath).existsSync(), isTrue);

      // Verify backup is recorded in listBackups
      final listResult = await backupRepo.listBackups();
      expect(listResult.isSuccess, isTrue);
      expect(listResult.valueOrThrow.length, equals(1));
      expect(listResult.valueOrThrow.first.id, equals(meta.id));
    });

    test('verifyBackup confirms valid backup and detects file tampering', () async {
      final createResult = await backupRepo.createBackup(type: 'manual', createdBy: 1);
      final meta = createResult.valueOrThrow;

      // 1. Initial verification must pass
      final verifyInitial = await backupRepo.verifyBackup(meta.id);
      expect(verifyInitial.isSuccess, isTrue);
      expect(verifyInitial.valueOrThrow, isTrue);

      // 2. Tamper with the backup file
      final backupFile = File(meta.filePath);
      await backupFile.writeAsString('Tampered-Corrupted-Data-Payload');

      // 3. Verification must fail
      final verifyTampered = await backupRepo.verifyBackup(meta.id);
      expect(verifyTampered.isSuccess, isTrue);
      expect(verifyTampered.valueOrThrow, isFalse);

      // 4. Restore must abort on checksum mismatch
      final restoreAttempt = await backupRepo.restoreBackup(meta.id);
      expect(restoreAttempt.isFailure, isTrue);
      expect(
        restoreAttempt.fold(onSuccess: (_) => '', onFailure: (f) => f.message),
        contains('checksum mismatch'),
      );
    });

    test('restoreBackup restores verified database file accurately', () async {
      // 1. Create backup of initial database
      final createResult = await backupRepo.createBackup(type: 'manual', createdBy: 1);
      final meta = createResult.valueOrThrow;

      // 2. Alter the active database file (simulating later modifications or data loss)
      await dbFile.writeAsString('Modified-State-After-Accidental-Delete');
      expect(await dbFile.readAsString(), equals('Modified-State-After-Accidental-Delete'));

      // 3. Perform restore
      final restoreResult = await backupRepo.restoreBackup(meta.id);
      expect(restoreResult.isSuccess, isTrue);

      // 4. Database file must now match the backup original content
      final restoredContent = await dbFile.readAsString();
      expect(restoredContent, equals('SQLCipher-Encrypted-Database-Content-V1'));
    });
  });
}
