/// Error banner widget for displaying failure messages.
library;

import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {

  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.overdueBg,
        border: Border.all(color: AppColors.overdue.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.overdue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.overdue,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success banner widget.
class SuccessBanner extends StatelessWidget {

  const SuccessBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paidBg,
        border: Border.all(color: AppColors.paid.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.paid, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.paid, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
