/// Colored status badge (Paid / Pending / Overdue / Partial).
library;

import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

enum StatusBadgeType { paid, pending, overdue, partial, active, inactive }

class StatusBadge extends StatelessWidget {
  final StatusBadgeType type;
  final String? label;

  const StatusBadge({super.key, required this.type, this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text) = switch (type) {
      StatusBadgeType.paid => (AppColors.paidBg, AppColors.paid, label ?? 'Paid'),
      StatusBadgeType.pending => (AppColors.pendingBg, AppColors.pending, label ?? 'Pending'),
      StatusBadgeType.overdue => (AppColors.overdueBg, AppColors.overdue, label ?? 'Overdue'),
      StatusBadgeType.partial => (AppColors.partialBg, AppColors.partial, label ?? 'Partial'),
      StatusBadgeType.active => (AppColors.paidBg, AppColors.paid, label ?? 'Active'),
      StatusBadgeType.inactive => (
          const Color(0xFFF1F5F9),
          AppColors.textMuted,
          label ?? 'Inactive',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
