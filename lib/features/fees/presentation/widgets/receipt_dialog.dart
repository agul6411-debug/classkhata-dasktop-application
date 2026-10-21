/// Printable and Shareable Fee Receipt dialog with WhatsApp picture export,
/// QR code verification, and clipboard integration.
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/payment_modes.dart';
import '../../../../core/money/money.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../core/services/receipt_image_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../domain/entities/fee_entities.dart';

class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({
    super.key,
    this.receipt,
    required this.studentName,
    required this.guardianPhone,
    required this.voucherNumber,
    this.paymentMode,
    this.academyName = 'School Name',
    this.rollNumber,
    this.batchName,
    this.academyPhone,
    this.academyAddress,
    this.voucher,
    this.guardianName,
  });

  final Receipt? receipt;
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

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final GlobalKey _receiptCardKey = GlobalKey();
  bool _isGenerating = false;

  String get effectiveReceiptNumber {
    if (widget.receipt != null) {
      return widget.receipt!.receiptNumber;
    }
    return 'CHL-${widget.voucherNumber}';
  }

  Money get effectiveAmount {
    if (widget.receipt != null) {
      return widget.receipt!.amount;
    }
    if (widget.voucher != null) {
      return widget.voucher!.balanceRemaining.paisa > 0
          ? widget.voucher!.balanceRemaining
          : widget.voucher!.totalDue;
    }
    return const Money.zero();
  }

  DateTime get effectiveDate {
    if (widget.receipt != null) {
      return widget.receipt!.receiptDate;
    }
    if (widget.voucher != null) {
      return widget.voucher!.issueDate;
    }
    return DateTime.now();
  }

  String get effectiveQrData {
    if (widget.receipt != null) {
      return widget.receipt!.qrData;
    }
    return 'CLASSTABLE:VOUCHER:${widget.voucherNumber}';
  }

  bool get isPaidInFull {
    if (widget.voucher != null) {
      return widget.voucher!.isPaidInFull;
    }
    return true;
  }

  bool get isChallan => widget.receipt == null;

  /// Formats an official, itemized digital fee receipt text (fallback for SMS or plain copy).
  String generateReceiptText() {
    final modeLabel = widget.paymentMode != null
        ? PaymentModes.getDisplayName(widget.paymentMode!)
        : 'Hand Cash';
    final date = effectiveDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final FeeVoucher? v = widget.voucher;
    final Money totalBill = v != null ? v.totalDue : effectiveAmount;
    final Money baseAmt = v != null ? v.baseAmount : effectiveAmount;
    final Money carryOver = v != null ? v.carryForward : const Money.zero();
    final Money lateFee = v != null ? v.lateFee : const Money.zero();
    final Money discount = v != null ? v.discount : const Money.zero();
    final Money remaining = v != null ? v.balanceRemaining : const Money.zero();

    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🏫 *${widget.academyName}*');
    buffer.writeln(isChallan ? '📜 *OFFICIAL FEE CHALLAN & DUE SLIP*' : '📜 *OFFICIAL FEE PAYMENT RECEIPT*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🧾 *Receipt/Challan No :* $effectiveReceiptNumber');
    buffer.writeln('📅 *Date               :* $dateStr');
    buffer.writeln('📋 *Voucher No         :* ${widget.voucherNumber}');
    buffer.writeln('💳 *Status             :* ${isPaidInFull ? "PAID IN FULL ✅" : (remaining == totalBill ? "DUE / PENDING ⚠️" : "PARTIAL PAYMENT ⏳")}');
    buffer.writeln();
    buffer.writeln('👤 *STUDENT DETAILS*');
    buffer.writeln('• *Student Name :* ${widget.studentName}');
    if (widget.rollNumber != null && widget.rollNumber!.isNotEmpty) {
      buffer.writeln('• *Roll Number  :* ${widget.rollNumber}');
    }
    if (widget.guardianName != null && widget.guardianName!.isNotEmpty) {
      buffer.writeln('• *Father/Guard.:* ${widget.guardianName}');
    }
    if (widget.batchName != null && widget.batchName!.isNotEmpty) {
      buffer.writeln('• *Class/Grade  :* ${widget.batchName}');
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
      buffer.writeln('• *Amount Paid Now  : ${v.amountPaid.format()}*');
      buffer.writeln('• *Remaining Balance: ${remaining.format()}*');
    } else {
      buffer.writeln('• *Amount Paid: ${effectiveAmount.format()}*');
    }
    buffer.writeln('──────────────────────────');
    if (widget.paymentMode != null) {
      buffer.writeln('💳 *PAYMENT METHOD*');
      buffer.writeln('• Received Via : $modeLabel');
      buffer.writeln();
    }
    if (widget.academyPhone != null && widget.academyPhone!.isNotEmpty) {
      buffer.writeln('📞 Contact: ${widget.academyPhone}');
    }
    if (widget.academyAddress != null && widget.academyAddress!.isNotEmpty) {
      buffer.writeln('📍 Location: ${widget.academyAddress}');
    }
    buffer.writeln();
    buffer.writeln('_Note: Verified digital computer-generated receipt._');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }

  /// Exports the receipt as a high-resolution PNG picture, copies it to the Windows
  /// clipboard, and opens the parent's WhatsApp chat with paste instructions.
  Future<void> _shareOnWhatsAppAsPicture(BuildContext context) async {
    setState(() => _isGenerating = true);

    try {
      final boundary =
          _receiptCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Receipt card render boundary is not ready.');
      }

      // Render at 2.5x pixel ratio for retina-quality 1100x1700+ resolution
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image to PNG.');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save PNG picture to Documents/ClassKhata/Receipts/
      final savedFile = await ReceiptImageService.saveReceiptImage(
        pngBytes: pngBytes,
        receiptNumber: effectiveReceiptNumber,
      );

      // Copy PNG image to Windows Clipboard (as both FileDrop and Bitmap)
      await ReceiptImageService.copyImageToWindowsClipboard(savedFile.path);

      // Automatically highlight picture in Windows File Explorer
      await ReceiptImageService.openFileInExplorer(savedFile.path);

      // Open parent's WhatsApp chat
      await ReceiptImageService.openWhatsAppChat(phone: widget.guardianPhone);

      if (!context.mounted) return;

      // Show instruction guide dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.cardBg(ctx),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF25D366), size: 28),
              SizedBox(width: 10),
              Text('Receipt Picture Ready!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aapka WhatsApp chat open ho gaya hai aur receipt ki PICTURE clipboard par copy ho chuki hai.',
                style: TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard, color: Color(0xFF166534), size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WhatsApp chat box mein cursor click karein aur keyboard se Ctrl + V (Paste) press karein, picture foran attach ho jaye gi!',
                        style: TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.image, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saved: ${savedFile.path}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Open Picture File'),
              onPressed: () {
                ReceiptImageService.openFileInExplorer(savedFile.path);
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Theek Hai (Done)'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _copyTextReceipt(BuildContext context) async {
    final text = generateReceiptText();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt text copied to clipboard!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  void _printSlip(BuildContext context) {
    // If receipt is null, create a temporary receipt object for printing
    final printReceipt = widget.receipt ??
        Receipt(
          id: widget.voucher?.id ?? 0,
          receiptNumber: effectiveReceiptNumber,
          voucherId: widget.voucher?.id ?? 0,
          studentId: widget.voucher?.studentId ?? 0,
          amount: effectiveAmount,
          qrData: effectiveQrData,
          receiptDate: effectiveDate,
          isCancelled: false,
        );

    PdfPrintPreviewDialog.show(
      context,
      title: 'Fee Receipt Preview ($effectiveReceiptNumber)',
      initialFormat: PdfPageFormat.roll80,
      pdfFileName: '$effectiveReceiptNumber.pdf',
      buildPdf: (format) => PdfDocumentService.generateFeeReceiptPdf(
        receipt: printReceipt,
        studentName: widget.studentName,
        voucherNumber: widget.voucherNumber,
        rollNumber: widget.rollNumber,
        batchName: widget.batchName,
        paymentMode: widget.paymentMode,
        academyName: widget.academyName,
        academyPhone: widget.academyPhone,
        academyAddress: widget.academyAddress,
        voucher: widget.voucher,
        guardianName: widget.guardianName,
        format: format,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FeeVoucher? v = widget.voucher;
    final Money totalBill = v != null ? v.totalDue : effectiveAmount;
    final Money remaining = v != null ? v.balanceRemaining : const Money.zero();
    final date = effectiveDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    // Status pill coloring
    final Color statusBg = isPaidInFull
        ? const Color(0xFFDCFCE7)
        : (remaining == totalBill ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    final Color statusBorder = isPaidInFull
        ? const Color(0xFF86EFAC)
        : (remaining == totalBill ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D));
    final Color statusTextColor = isPaidInFull
        ? const Color(0xFF166534)
        : (remaining == totalBill ? const Color(0xFF991B1B) : const Color(0xFF92400E));
    final String statusLabel = isPaidInFull
        ? 'PAID IN FULL ✅'
        : (remaining == totalBill ? 'PAYMENT DUE ⚠️' : 'PARTIAL PAYMENT ⏳');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderCol(context)),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Action Bar / Close
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 16, right: 12, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isChallan ? Icons.receipt_long : Icons.verified,
                            color: const Color(0xFF25D366),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isChallan ? 'Fee Challan Slip' : 'Fee Payment Slip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.headingCol(context),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),

                // RECEIPT CARD (Wrapped in RepaintBoundary for Picture Export)
                // Designed with authentic white paper background for crystal-clear sharing
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: RepaintBoundary(
                    key: _receiptCardKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header: Deep Royal Navy Blue
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E3A8A), // Royal navy blue
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.academyName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isChallan
                                            ? 'OFFICIAL FEE CHALLAN & DUE NOTICE'
                                            : 'OFFICIAL FEE PAYMENT RECEIPT',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10.5,
                                          letterSpacing: 1.1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isChallan ? Icons.receipt_long : Icons.check_circle,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),

                          // Slip Body
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                // Amount Display
                                Text(
                                  effectiveAmount.format(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    effectiveReceiptNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A8A),
                                      letterSpacing: 1.2,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusBorder),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Divider(height: 20, color: Color(0xFFE2E8F0)),

                                // Student Information Box
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      _slipRow('Student Name', widget.studentName, isBold: true),
                                      if (widget.rollNumber != null && widget.rollNumber!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _slipRow('Roll Number', widget.rollNumber!),
                                      ],
                                      if (widget.guardianName != null && widget.guardianName!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _slipRow('Father / Guardian', widget.guardianName!),
                                      ],
                                      if (widget.batchName != null && widget.batchName!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _slipRow('Class / Section', widget.batchName!),
                                      ],
                                      const SizedBox(height: 4),
                                      _slipRow('Voucher Number', widget.voucherNumber),
                                      const SizedBox(height: 4),
                                      _slipRow('Date', dateStr),
                                      if (widget.paymentMode != null) ...[
                                        const SizedBox(height: 4),
                                        _slipRow('Payment Mode', PaymentModes.getDisplayName(widget.paymentMode!)),
                                      ],
                                    ],
                                  ),
                                ),

                                // Itemized Fee Calculation Table
                                if (v != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Fee Calculation Breakdown (${v.monthYear})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        _slipCalcRow('Monthly Tuition Fee:', v.baseAmount.format()),
                                        if (v.carryForward.paisa > 0)
                                          _slipCalcRow('Previous Arrears:', v.carryForward.format(), isWarning: true),
                                        if (v.lateFee.paisa > 0)
                                          _slipCalcRow('Late Fee Surcharge:', v.lateFee.format(), isWarning: true),
                                        if (v.discount.paisa > 0)
                                          _slipCalcRow('Concession / Discount:', '- ${v.discount.format()}', isDiscount: true),
                                        const Divider(height: 10, color: Color(0xFFCBD5E1)),
                                        _slipCalcRow('Total Invoiced:', totalBill.format(), bold: true),
                                        _slipCalcRow('Amount Paid:', v.amountPaid.format(), bold: true),
                                        _slipCalcRow(
                                          'Remaining Balance:',
                                          remaining.format(),
                                          bold: true,
                                          isWarning: remaining.paisa > 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                if (widget.academyPhone != null && widget.academyPhone!.isNotEmpty)
                                  Text(
                                    '📞 ${widget.academyPhone}',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                  ),
                                if (widget.academyAddress != null && widget.academyAddress!.isNotEmpty)
                                  Text(
                                    '📍 ${widget.academyAddress}',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.academyName} • Official Digital Receipt',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 18, left: 16, right: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // 🟢 SEND WHATSAPP PICTURE BUTTON
                          Expanded(
                            flex: 6,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_camera, size: 18),
                              label: Text(
                                _isGenerating ? 'Generating Picture...' : 'Send WhatsApp Picture',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: _isGenerating ? null : () => _shareOnWhatsAppAsPicture(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 🖨️ PRINT SLIP BUTTON
                          Expanded(
                            flex: 4,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text('Print Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _printSlip(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy Text Receipt', style: TextStyle(fontSize: 11)),
                            onPressed: () => _copyTextReceipt(context),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close', style: TextStyle(fontSize: 12)),
                          ),
                        ],
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

  Widget _slipRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 11.5,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _slipCalcRow(
    String label,
    String value, {
    bool bold = false,
    bool isWarning = false,
    bool isDiscount = false,
  }) {
    Color color = bold ? const Color(0xFF0F172A) : const Color(0xFF475569);
    if (isWarning) color = const Color(0xFFC2410C); // dark orange
    if (isDiscount) color = const Color(0xFF15803D); // dark green

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
