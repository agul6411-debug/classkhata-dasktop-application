import 'dart:typed_data';

import 'package:classkhata/shared/widgets/pdf_print_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  testWidgets('PdfPrintPreviewDialog shows title, preview container, and closes on close button', (tester) async {
    // Set desktop window size
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    Future<Uint8List> dummyPdfBuilder(PdfPageFormat format) async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (ctx) => pw.Center(child: pw.Text('Test Preview')),
        ),
      );
      return doc.save();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                PdfPrintPreviewDialog.show(
                  context,
                  title: 'Official Voucher Preview',
                  buildPdf: dummyPdfBuilder,
                );
              },
              child: const Text('Open Preview'),
            ),
          ),
        ),
      ),
    );

    // Tap to open preview dialog
    await tester.tap(find.text('Open Preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify title is rendered
    expect(find.text('Official Voucher Preview'), findsOneWidget);

    // Verify close icon button exists
    final closeBtn = find.byIcon(Icons.close);
    expect(closeBtn, findsOneWidget);

    // Tap close button
    await tester.tap(closeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog is dismissed
    expect(find.text('Official Voucher Preview'), findsNothing);
  });
}
