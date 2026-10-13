/// Printable Receipt dialog with QR code verification and WhatsApp sharing.
library;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../domain/entities/fee_entities.dart';

class ReceiptDialog extends StatelessWidget {
  final Receipt receipt;
  final String studentName;
  final String guardianPhone;
  final String voucherNumber;
  final String academyName;
  final String? rollNumber;
  final String? batchName;
  final String? academyPhone;
  final String? academyAddress;

  const ReceiptDialog({
    super.key,
    required this.receipt,
    required this.studentName,
    required this.guardianPhone,
    required this.voucherNumber,
    this.academyName = 'ClassKhata Academy',
    this.rollNumber,
    this.batchName,
    this.academyPhone,
    this.academyAddress,
  });

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final cleanPhone = guardianPhone.replaceAll(RegExp(r'[^0-9]'), '');
    // Standard Pakistani phone formatting if starting with 03
    final formattedPhone = cleanPhone.startsWith('03') ? '92${cleanPhone.substring(1)}' : cleanPhone;
    final message = Uri.encodeComponent(
      'Dear Guardian, payment of ${receipt.amount.format()} received for $studentName against $voucherNumber. Receipt: ${receipt.receiptNumber}. Thank you, $academyName.',
    );
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2),
            ],
          ),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          academyName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          'OFFICIAL FEE PAYMENT RECEIPT',
                          style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                    const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      receipt.amount.format(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receipt.receiptNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Divider(height: 28),
                    _infoRow('Student', studentName),
                    const SizedBox(height: 8),
                    _infoRow('Voucher', voucherNumber),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Date',
                      '${receipt.receiptDate.day}/${receipt.receiptDate.month}/${receipt.receiptDate.year}',
                    ),
                    const SizedBox(height: 16),
                    // Verification QR Code
                    Center(
                      child: QrImageView(
                        data: receipt.qrData,
                        version: QrVersions.auto,
                        size: 110,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Scan to verify receipt authenticity',
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
                        icon: const Icon(Icons.share, size: 16, color: Colors.green),
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.green)),
                        onPressed: () => _shareOnWhatsApp(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Preview'),
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
                              academyName: academyName,
                              academyPhone: academyPhone,
                              academyAddress: academyAddress,
                              format: format,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
