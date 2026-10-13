/// Colored status badge (Paid / Pending / Overdue / Partial).
library;

import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

enum StatusBadgeType { paid, pending, overdue, partial, active, inactive }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.type, this.label});
  final StatusBadgeType type;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bg, fg, border, text) = switch (type) {
      StatusBadgeType.paid => isDark
          ? (const Color(0xFF064E3B).withValues(alpha: 0.65), const Color(0xFF4ADE80), const Color(0xFF059669).withValues(alpha: 0.4), label ?? 'Paid')
          : (AppColors.paidBg, AppColors.paid, Colors.transparent, label ?? 'Paid'),
      StatusBadgeType.pending => isDark
          ? (const Color(0xFF78350F).withValues(alpha: 0.65), const Color(0xFFFBBF24), const Color(0xFFD97706).withValues(alpha: 0.4), label ?? 'Pending')
          : (AppColors.pendingBg, AppColors.pending, Colors.transparent, label ?? 'Pending'),
      StatusBadgeType.overdue => isDark
          ? (const Color(0xFF7F1D1D).withValues(alpha: 0.65), const Color(0xFFF87171), const Color(0xFFDC2626).withValues(alpha: 0.4), label ?? 'Overdue')
          : (AppColors.overdueBg, AppColors.overdue, Colors.transparent, label ?? 'Overdue'),
      StatusBadgeType.partial => isDark
          ? (const Color(0xFF0C4A6E).withValues(alpha: 0.65), const Color(0xFF38BDF8), const Color(0xFF0284C7).withValues(alpha: 0.4), label ?? 'Partial')
          : (AppColors.partialBg, AppColors.partial, Colors.transparent, label ?? 'Partial'),
      StatusBadgeType.active => isDark
          ? (const Color(0xFF064E3B).withValues(alpha: 0.65), const Color(0xFF4ADE80), const Color(0xFF059669).withValues(alpha: 0.4), label ?? 'Active')
          : (AppColors.paidBg, AppColors.paid, Colors.transparent, label ?? 'Active'),
      StatusBadgeType.inactive => isDark
          ? (const Color(0xFF334155).withValues(alpha: 0.65), const Color(0xFF94A3B8), const Color(0xFF475569).withValues(alpha: 0.4), label ?? 'Inactive')
          : (const Color(0xFFF1F5F9), AppColors.textMuted, Colors.transparent, label ?? 'Inactive'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
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
