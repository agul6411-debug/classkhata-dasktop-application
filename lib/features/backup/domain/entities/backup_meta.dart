/// Backup domain entities.
library;

class BackupMeta {

  const BackupMeta({
    required this.id,
    required this.filePath,
    required this.type,
    required this.sizeBytes,
    required this.checksum,
    required this.isVerified,
    required this.createdAt,
  });
  final int id;
  final String filePath;
  final String type; // manual | auto | pre_migration
  final int sizeBytes;
  final String checksum;
  final bool isVerified;
  final DateTime createdAt;
}
