/// Payment modes commonly used in Pakistan (Hand Cash, Bank, EasyPaisa, JazzCash).
library;

import 'package:flutter/material.dart';

class PaymentModes {
  PaymentModes._();

  static const String handCash = 'hand_cash';
  static const String bank = 'bank';
  static const String easyPaisa = 'easypaisa';
  static const String jazzCash = 'jazzcash';

  /// Returns user-facing label with English script.
  static String getDisplayName(String? mode) {
    if (mode == null) return 'Hand Cash';
    final m = mode.trim().toLowerCase();
    switch (m) {
      case 'hand_cash':
      case 'cash':
        return 'Hand Cash';
      case 'bank':
        return 'Bank Transfer';
      case 'easypaisa':
        return 'EasyPaisa';
      case 'jazzcash':
        return 'JazzCash';
      case 'online':
        return 'Online / Mobile';
      default:
        return mode.toUpperCase();
    }
  }

  /// English-only display name safe for PDF generation using standard 14 PostScript fonts.
  static String getPdfDisplayName(String? mode) {
    if (mode == null) return 'Hand Cash';
    final m = mode.trim().toLowerCase();
    switch (m) {
      case 'hand_cash':
      case 'cash':
        return 'Hand Cash';
      case 'bank':
        return 'Bank Transfer';
      case 'easypaisa':
        return 'EasyPaisa';
      case 'jazzcash':
        return 'JazzCash';
      case 'online':
        return 'Online / Mobile';
      default:
        return mode.toUpperCase();
    }
  }

  /// Dropdown menu items for UI forms across Fees, Finance, Payroll, and Inventory.
  static List<DropdownMenuItem<String>> get dropdownItems => const [
        DropdownMenuItem(
          value: handCash,
          child: Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Text('Hand Cash'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: bank,
          child: Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 16, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Bank Transfer'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: easyPaisa,
          child: Row(
            children: [
              Icon(Icons.phone_android_outlined, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text('EasyPaisa'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: jazzCash,
          child: Row(
            children: [
              Icon(Icons.mobile_friendly_outlined, size: 16, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text('JazzCash'),
            ],
          ),
        ),
      ];
}
