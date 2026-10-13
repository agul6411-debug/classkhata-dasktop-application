/// Printable Receipt dialog with QR code verification and WhatsApp sharing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/payment_modes.dart';
import '../../../../core/money/money.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../domain/entities/fee_entities.dart';

class ReceiptDialog extends StatelessWidget {

  const ReceiptDialog({
    super.key,
    required this.receipt,
    required this.studentName,
    required this.guardianPhone,
    required this.voucherNumber,
    this.paymentMode,
    this.academyName = 'ClassKhata Academy',
    this.rollNumber,
    this.batchName,
    this.academyPhone,
    this.academyAddress,
    this.voucher,
    this.guardianName,
  });
  final Receipt receipt;
  final String studentName;
  final String guardianPhone;
  final String voucherNumber;
  final String? paymentMode;
  final String academyName;
  final String? rollNumber;
  final String? batchName;
  final String? academyPhone;
  final String? academyAddress;
  final FeeVoucher? voucher;
  final String? guardianName;

  /// Formats an official, itemized digital fee receipt with full amount calculation.
  String generateWhatsAppReceiptText() {
    final modeLabel = paymentMode != null ? PaymentModes.getDisplayName(paymentMode!) : 'Hand Cash';
    final dateStr =
        '${receipt.receiptDate.day.toString().padLeft(2, '0')}/${receipt.receiptDate.month.toString().padLeft(2, '0')}/${receipt.receiptDate.year}';

    final FeeVoucher? v = voucher;
    final Money totalBill = v != null ? v.totalDue : receipt.amount;
    final Money baseAmt = v != null ? v.baseAmount : receipt.amount;
    final Money carryOver = v != null ? v.carryForward : const Money.zero();
    final Money lateFee = v != null ? v.lateFee : const Money.zero();
    final Money discount = v != null ? v.discount : const Money.zero();
    final Money remaining = v != null ? v.balanceRemaining : const Money.zero();
    final bool isFullyPaid = remaining.isZero || remaining.isNegative;

    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🏫 *$academyName*');
    buffer.writeln('📜 *OFFICIAL FEE PAYMENT RECEIPT*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🧾 *Receipt No :* ${receipt.receiptNumber}');
    buffer.writeln('📅 *Date       :* $dateStr');
    buffer.writeln('📋 *Voucher No :* $voucherNumber');
    buffer.writeln('💳 *Status     :* ${isFullyPaid ? "PAID IN FULL ✅" : "PARTIAL PAYMENT ⏳"}');
    buffer.writeln();
    buffer.writeln('👤 *STUDENT DETAILS*');
    buffer.writeln('• *Student Name :* $studentName');
    if (rollNumber != null && rollNumber!.isNotEmpty) {
      buffer.writeln('• *Roll Number  :* $rollNumber');
    }
    if (guardianName != null && guardianName!.isNotEmpty) {
      buffer.writeln('• *Father/Guard.:* $guardianName');
    }
    if (batchName != null && batchName!.isNotEmpty) {
      buffer.writeln('• *Class/Grade  :* $batchName');
    }
    buffer.writeln();
    buffer.writeln('💰 *FEE CALCULATION BREAKDOWN*');
    if (v != null) {
      buffer.writeln('• Fee Month        : ${v.monthYear}');
      buffer.writeln('• Monthly Tuition  : ${baseAmt.format()}');
      if (carryOver.paisa > 0) {
        buffer.writeln('• Previous Arrears : ${carryOver.format()}');
      }
      if (lateFee.paisa > 0) {
        buffer.writeln('• Late Surcharge   : ${lateFee.format()}');
      }
      if (discount.paisa > 0) {
        buffer.writeln('• Concession/Disc. : -${discount.format()}');
      }
      buffer.writeln('──────────────────────────');
      buffer.writeln('• *Total Bill Due   : ${totalBill.format()}*');
    }
    buffer.writeln('• *Amount Paid Now : ${receipt.amount.format()}*');
    buffer.writeln('• *Remaining Balance: ${remaining.format()}*');
    buffer.writeln('──────────────────────────');
    buffer.writeln('💳 *PAYMENT METHOD*');
    buffer.writeln('• Received Via : $modeLabel');
    buffer.writeln();
    if (academyPhone != null && academyPhone!.isNotEmpty) {
      buffer.writeln('📞 Contact: $academyPhone');
    }
    if (academyAddress != null && academyAddress!.isNotEmpty) {
      buffer.writeln('📍 Location: $academyAddress');
    }
    buffer.writeln();
    buffer.writeln('_Note: Verified digital computer-generated receipt from ClassKhata._');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final cleanPhone = guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = cleanPhone.startsWith('03')
        ? '92${cleanPhone.substring(1)}'
        : cleanPhone.startsWith('0')
            ? '92${cleanPhone.substring(1)}'
            : cleanPhone;

    final receiptText = generateWhatsAppReceiptText();
    // Copy full receipt text to clipboard so user can also paste directly
    await Clipboard.setData(ClipboardData(text: receiptText));

    final encodedMessage = Uri.encodeComponent(receiptText);
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp receipt opened and copied to clipboard!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp. Receipt copied to clipboard.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FeeVoucher? v = voucher;
    final Money totalBill = v != null ? v.totalDue : receipt.amount;
    final Money remaining = v != null ? v.balanceRemaining : const Money.zero();
    final bool isFullyPaid = remaining.isZero || remaining.isNegative;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderCol(context)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, spreadRadius: 2),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              academyName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'OFFICIAL FEE PAYMENT RECEIPT',
                              style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: Colors.white, size: 28),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Text(
                        receipt.amount.format(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingCol(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        receipt.receiptNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFullyPaid ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isFullyPaid ? 'PAID IN FULL ✅' : 'PARTIAL PAYMENT ⏳',
                          style: TextStyle(
                            color: isFullyPaid ? const Color(0xFF6EE7B7) : const Color(0xFFFCD34D),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      _infoRow(context, 'Student', studentName),
                      if (rollNumber != null && rollNumber!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _infoRow(context, 'Roll Number', rollNumber!),
                      ],
                      if (guardianName != null && guardianName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _infoRow(context, 'Father / Guardian', guardianName!),
                      ],
                      if (batchName != null && batchName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _infoRow(context, 'Class / Section', batchName!),
                      ],
                      const SizedBox(height: 6),
                      _infoRow(context, 'Voucher Number', voucherNumber),
                      const SizedBox(height: 6),
                      _infoRow(
                        context,
                        'Payment Date',
                        '${receipt.receiptDate.day}/${receipt.receiptDate.month}/${receipt.receiptDate.year}',
                      ),
                      if (paymentMode != null) ...[
                        const SizedBox(height: 6),
                        _infoRow(context, 'Payment Mode', PaymentModes.getDisplayName(paymentMode!)),
                      ],

                      // Itemized Calculation Box
                      if (v != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.subCardBg(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderCol(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Fee Calculation Breakdown (${v.monthYear})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.headingCol(context),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _calcRow(context, 'Tuition Fee:', v.baseAmount.format()),
                              if (v.carryForward.paisa > 0)
                                _calcRow(context, 'Previous Arrears:', v.carryForward.format(), isWarning: true),
                              if (v.lateFee.paisa > 0)
                                _calcRow(context, 'Late Fee Surcharge:', v.lateFee.format(), isWarning: true),
                              if (v.discount.paisa > 0)
                                _calcRow(context, 'Concession / Discount:', '- ${v.discount.format()}', isDiscount: true),
                              Divider(height: 12, color: AppColors.borderCol(context)),
                              _calcRow(context, 'Total Invoiced:', totalBill.format(), bold: true),
                              _calcRow(context, 'Paid in this Receipt:', receipt.amount.format(), bold: true),
                              _calcRow(
                                context,
                                'Remaining Balance:',
                                remaining.format(),
                                bold: true,
                                isWarning: remaining.paisa > 0,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      // Verification QR Code
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderCol(context)),
                          ),
                          child: QrImageView(
                            data: receipt.qrData,
                            size: 90,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan to verify authentic fee voucher entry',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF25D366)),
                            foregroundColor: const Color(0xFF25D366),
                          ),
                          icon: const Icon(Icons.share, size: 16, color: Color(0xFF25D366)),
                          label: const Text('Send WhatsApp Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _shareOnWhatsApp(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Slip'),
                        onPressed: () {
                          PdfPrintPreviewDialog.show(
                            context,
                            title: 'Fee Receipt Preview (${receipt.receiptNumber})',
                            initialFormat: PdfPageFormat.roll80,
                            pdfFileName: '${receipt.receiptNumber}.pdf',
                            buildPdf: (format) => PdfDocumentService.generateFeeReceiptPdf(
                              receipt: receipt,
                              studentName: studentName,
                              voucherNumber: voucherNumber,
                              rollNumber: rollNumber,
                              batchName: batchName,
                              paymentMode: paymentMode,
                              academyName: academyName,
                              academyPhone: academyPhone,
                              academyAddress: academyAddress,
                              format: format,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMutedCol(context), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.headingCol(context),
          ),
        ),
      ],
    );
  }

  Widget _calcRow(BuildContext context, String label, String value,
      {bool bold = false, bool isWarning = false, bool isDiscount = false}) {
    Color? color = bold ? AppColors.headingCol(context) : AppColors.textSecondaryCol(context);
    if (isWarning) color = Colors.orange.shade700;
    if (isDiscount) color = Colors.green.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
