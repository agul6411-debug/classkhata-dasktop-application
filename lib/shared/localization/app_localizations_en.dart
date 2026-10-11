// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ClassKhata';

  @override
  String get loading => 'Loading…';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get search => 'Search';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Finish';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get submit => 'Submit';

  @override
  String get print => 'Print';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get refresh => 'Refresh';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navStudents => 'Students';

  @override
  String get navFees => 'Fees';

  @override
  String get navPayroll => 'Payroll';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get loginTitle => 'Welcome to ClassKhata';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get loginFailed => 'Invalid email or password.';

  @override
  String accountLocked(int minutes) {
    return 'Account is locked. Try again in $minutes minutes.';
  }

  @override
  String get setupTitle => 'Welcome to ClassKhata';

  @override
  String get setupSubtitle =>
      'Let\'s set up your academy in a few quick steps.';

  @override
  String get setupStep1 => 'Academy Profile';

  @override
  String get setupStep2 => 'Admin Account';

  @override
  String get setupStep3 => 'Recovery Key';

  @override
  String get academyName => 'Academy Name';

  @override
  String get academyTagline => 'Tagline (optional)';

  @override
  String get academyPhone => 'Phone Number';

  @override
  String get academyAddress => 'Address';

  @override
  String get adminName => 'Your Name';

  @override
  String get adminEmail => 'Admin Email';

  @override
  String get adminPassword => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get recoveryKeyTitle => 'Save Your Recovery Key';

  @override
  String get recoveryKeyWarning =>
      'This key is shown only once. Store it somewhere safe — it cannot be recovered if lost.';

  @override
  String get recoveryKeyCopied => 'Recovery key copied to clipboard.';

  @override
  String get setupComplete => 'Setup Complete';

  @override
  String get setupCompleteMsg => 'ClassKhata is ready to use.';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusPartial => 'Partial';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get errorPermission =>
      'You do not have permission to perform this action.';

  @override
  String get errorDatabase =>
      'A database error occurred. Please contact support.';

  @override
  String get errorValidation => 'Please check the highlighted fields.';

  @override
  String get currency => 'Rs.';

  @override
  String get noData => 'No data found.';

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String get confirmDeleteMessage =>
      'Are you sure you want to delete this item? This action cannot be undone.';

  @override
  String get backupSuccess => 'Backup created successfully.';

  @override
  String get backupFailed => 'Backup failed. Please try again.';

  @override
  String get restoreSuccess => 'Database restored successfully.';

  @override
  String get restoreFailed =>
      'Restore failed. The backup file may be corrupted.';

  @override
  String get auditIntegrityOk => 'Audit log integrity check passed.';

  @override
  String get auditIntegrityFailed =>
      'Audit log integrity check FAILED. The log may have been tampered with.';

  @override
  String trialDaysRemaining(int days) {
    return '$days days remaining in your trial.';
  }

  @override
  String get trialExpired =>
      'Your trial has expired. Please activate a license.';

  @override
  String get licenseActive => 'License active.';

  @override
  String get autoLockMessage => 'Session locked due to inactivity.';

  @override
  String get unlockSession => 'Unlock Session';
}
