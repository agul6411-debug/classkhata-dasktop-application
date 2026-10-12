/// Licensing domain models and status representations.
library;

import 'package:equatable/equatable.dart';

enum LicenseStatus {
  trial,
  active,
  expired,
  clockRollbackDetected,
  tampered,
}

class LicenseInfo extends Equatable {
  final LicenseStatus status;
  final String machineId;
  final DateTime trialStartedAt;
  final int daysRemaining;
  final String? academyName;
  final String? licenseKey;
  final DateTime? activatedAt;
  final String? alertMessage;

  const LicenseInfo({
    required this.status,
    required this.machineId,
    required this.trialStartedAt,
    required this.daysRemaining,
    this.academyName,
    this.licenseKey,
    this.activatedAt,
    this.alertMessage,
  });

  /// When in read-only mode, data is viewable and exportable, but
  /// new financial entries (payments, expenses, salary payouts, purchases) are forbidden.
  bool get isReadonly =>
      status == LicenseStatus.expired ||
      status == LicenseStatus.clockRollbackDetected ||
      status == LicenseStatus.tampered;

  bool get isActivated => status == LicenseStatus.active;

  bool get isTrial => status == LicenseStatus.trial;

  bool get canPerformFinancialWrites => !isReadonly;

  @override
  List<Object?> get props => [
        status,
        machineId,
        trialStartedAt,
        daysRemaining,
        academyName,
        licenseKey,
        activatedAt,
        alertMessage,
      ];
}
