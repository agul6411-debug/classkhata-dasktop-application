/// Desktop-optimized PDF Print Preview dialog using `package:printing/printing.dart`.
/// Allows real-time inspection, page format switching (A4 / 80mm Roll / A5),
/// direct printer output, and PDF file saving.
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../app/theme/app_theme.dart';

class PdfPrintPreviewDialog extends StatelessWidget {

  const PdfPrintPreviewDialog({
    super.key,
    required this.title,
    required this.buildPdf,
    this.initialFormat = PdfPageFormat.a4,
    this.pageFormats,
    this.pdfFileName = 'document.pdf',
  });
  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final PdfPageFormat initialFormat;
  final Map<String, PdfPageFormat>? pageFormats;
  final String pdfFileName;

  /// Displays the print preview dialog modally.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Future<Uint8List> Function(PdfPageFormat format) buildPdf,
    PdfPageFormat initialFormat = PdfPageFormat.a4,
    Map<String, PdfPageFormat>? pageFormats,
    String pdfFileName = 'document.pdf',
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PdfPrintPreviewDialog(
        title: title,
        buildPdf: buildPdf,
        initialFormat: initialFormat,
        pageFormats: pageFormats,
        pdfFileName: pdfFileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.88).clamp(600.0, 1020.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(520.0, 840.0);

    final defaultFormats = pageFormats ?? {
      'A4': PdfPageFormat.a4,
      'Thermal 80mm': PdfPageFormat.roll80,
      'A5': PdfPageFormat.a5,
      'Letter': PdfPageFormat.letter,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderCol(context)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.subCardBg(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: AppColors.borderCol(context))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingCol(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    tooltip: 'Close Preview',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Embedded PDF Preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: PdfPreview(
                  build: buildPdf,
                  initialPageFormat: initialFormat,
                  pageFormats: defaultFormats,
                  canDebug: false,
                  pdfFileName: pdfFileName,
                  loadingWidget: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Rendering Print Preview...', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  previewPageMargin: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
