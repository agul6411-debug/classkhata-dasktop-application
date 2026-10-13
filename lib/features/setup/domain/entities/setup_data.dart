/// Setup domain entities — pure Dart.
library;

/// The data collected during the first-run setup wizard.
class SetupData {

  const SetupData({
    required this.academyName,
    this.tagline,
    this.phone,
    this.address,
    required this.adminName,
    required this.adminEmail,
    required this.adminPassword,
  });
  // Step 1: Academy profile
  final String academyName;
  final String? tagline;
  final String? phone;
  final String? address;

  // Step 2: Admin account
  final String adminName;
  final String adminEmail;
  final String adminPassword;
}
