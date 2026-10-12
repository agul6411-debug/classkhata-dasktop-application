/// Banner displaying trial days remaining and read-only mode alerts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../entities/license_entities.dart';
import '../providers/licensing_providers.dart';
import 'activation_dialog.dart';

class LicenseBanner extends ConsumerWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(licenseInfoProvider);

    return infoAsync.when(
      data: (info) {
        if (info.isActivated) {
          return const SizedBox.shrink();
        }

        final isUrgent = info.isReadonly || (info.isTrial && info.daysRemaining <= 3);

        Color bgColor;
        Color textColor;
        Color borderColor;
        IconData icon;
        String text;

        if (info.status == LicenseStatus.expired) {
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade900;
          borderColor = Colors.red.shade200;
          icon = Icons.lock_outline;
          text = 'Trial Expired — System in Read-Only mode. Data remains viewable & exportable.';
        } else if (info.status == LicenseStatus.clockRollbackDetected) {
          bgColor = Colors.orange.shade50;
          textColor = Colors.orange.shade900;
          borderColor = Colors.orange.shade300;
          icon = Icons.access_time_filled;
          text = 'Clock Rollback Detected — Financial entry creation is temporarily disabled.';
        } else if (info.status == LicenseStatus.tampered) {
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade900;
          borderColor = Colors.red.shade200;
          icon = Icons.security_update_warning;
          text = 'Licensing Integrity Alert — Please reactivate your lifetime license.';
        } else {
          // Trial mode
          bgColor = info.daysRemaining <= 3 ? Colors.amber.shade50 : Colors.teal.shade50;
          textColor = info.daysRemaining <= 3 ? Colors.brown.shade900 : Colors.teal.shade900;
          borderColor = info.daysRemaining <= 3 ? Colors.amber.shade300 : Colors.teal.shade200;
          icon = Icons.timer_outlined;
          text = 'Trial Mode: ${info.daysRemaining} day${info.daysRemaining == 1 ? '' : 's'} remaining.';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isUrgent ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_outlined, size: 14),
                label: const Text('Activate License'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    builder: (_) => ActivationDialog(machineId: info.machineId),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
