/// Banner displaying trial days remaining and read-only mode alerts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/license_entities.dart';
import '../providers/licensing_providers.dart';
import 'activation_dialog.dart';

class LicenseBanner extends ConsumerWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(licenseInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          bgColor = isDark ? const Color(0xFF450A0A) : Colors.red.shade50;
          textColor = isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900;
          borderColor = isDark ? const Color(0xFF991B1B) : Colors.red.shade200;
          icon = Icons.lock_outline;
          text = 'Trial Expired — System in Read-Only mode. Data remains viewable & exportable.';
        } else if (info.status == LicenseStatus.clockRollbackDetected) {
          bgColor = isDark ? const Color(0xFF431407) : Colors.orange.shade50;
          textColor = isDark ? const Color(0xFFFDBA74) : Colors.orange.shade900;
          borderColor = isDark ? const Color(0xFF9A3412) : Colors.orange.shade300;
          icon = Icons.access_time_filled;
          text = 'Clock Rollback Detected — Financial entry creation is temporarily disabled.';
        } else if (info.status == LicenseStatus.tampered) {
          bgColor = isDark ? const Color(0xFF450A0A) : Colors.red.shade50;
          textColor = isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900;
          borderColor = isDark ? const Color(0xFF991B1B) : Colors.red.shade200;
          icon = Icons.security_update_warning;
          text = 'Licensing Integrity Alert — Please reactivate your lifetime license.';
        } else {
          // Trial mode
          if (info.daysRemaining <= 3) {
            bgColor = isDark ? const Color(0xFF451A03) : Colors.amber.shade50;
            textColor = isDark ? const Color(0xFFFDE68A) : Colors.brown.shade900;
            borderColor = isDark ? const Color(0xFFB45309) : Colors.amber.shade300;
          } else {
            bgColor = isDark ? const Color(0xFF042F2E) : Colors.teal.shade50;
            textColor = isDark ? const Color(0xFF99F6E4) : Colors.teal.shade900;
            borderColor = isDark ? const Color(0xFF115E59) : Colors.teal.shade200;
          }
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
