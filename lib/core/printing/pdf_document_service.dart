/// Centralized PDF generation service for ClassKhata.
/// Generates official Fee Receipts, 3-copy Fee Vouchers, Salary Payslips,
/// Student ID Cards, and Fee Cards for printing and print preview.
library;

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/fees/domain/entities/fee_entities.dart';
import '../../features/payroll/domain/entities/payroll_entities.dart';
import '../../features/students/domain/entities/student_entities.dart';
import '../constants/payment_modes.dart';
import '../money/money.dart';

class PdfDocumentService {
  PdfDocumentService._();

  // ---------------------------------------------------------------------------
  // 1. Fee Receipt PDF (Thermal 80mm roll or Standard A4 / A5)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generateFeeReceiptPdf({
    required Receipt receipt,
    required String studentName,
    required String voucherNumber,
    String? rollNumber,
    String? batchName,
    String? paymentMode,
    required String academyName,
    String? academyPhone,
    String? academyAddress,
    FeeVoucher? voucher,
    String? guardianName,
    PdfPageFormat format = PdfPageFormat.roll80,
  }) async {
    final doc = pw.Document();
    final isThermal = format.width < 300; // roll80 is ~204-226 points

    if (isThermal) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    academyName,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (academyAddress != null && academyAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      academyAddress,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                if (academyPhone != null && academyPhone.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'Tel: $academyPhone',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text(
                    'FEE PAYMENT RECEIPT',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                _thermalRow('Receipt No:', receipt.receiptNumber, bold: true),
                _thermalRow(
                  'Date:',
                  '${receipt.receiptDate.day}/${receipt.receiptDate.month}/${receipt.receiptDate.year}',
                ),
                _thermalRow('Voucher:', voucherNumber),
                _thermalRow('Student:', studentName),
                if (rollNumber != null && rollNumber.isNotEmpty)
                  _thermalRow('Roll No:', rollNumber),
                if (batchName != null && batchName.isNotEmpty)
                  _thermalRow('Class/Batch:', batchName),
                if (paymentMode != null && paymentMode.isNotEmpty)
                  _thermalRow('Payment Mode:', PaymentModes.getPdfDisplayName(paymentMode)),
                if (voucher != null) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Text('CALCULATION (${voucher.monthYear}):',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  _thermalRow('Tuition Fee:', voucher.baseAmount.format()),
                  if (voucher.carryForward.paisa > 0) _thermalRow('Prev Arrears:', voucher.carryForward.format()),
                  if (voucher.lateFee.paisa > 0) _thermalRow('Late Surcharge:', voucher.lateFee.format()),
                  if (voucher.discount.paisa > 0) _thermalRow('Concession:', '- ${voucher.discount.format()}'),
                  _thermalRow('Total Billed:', voucher.totalDue.format(), bold: true),
                  _thermalRow('Balance Due:', voucher.balanceRemaining.format(), bold: true),
                ],
                pw.Divider(thickness: 0.8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT PAID:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      receipt.amount.format(),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.8),
                pw.SizedBox(height: 6),
                // Vector QR Code
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: receipt.qrData,
                    barcode: pw.Barcode.qrCode(),
                    width: 75,
                    height: 75,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Scan to verify receipt authenticity',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.5),
                pw.Center(
                  child: pw.Text(
                    'Thank you for your payment!',
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    academyName,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // Standard A4 / A5 receipt format
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // School Letterhead Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            academyName,
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                          ),
                          if (academyAddress != null && academyAddress.isNotEmpty)
                            pw.Text(academyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (academyPhone != null && academyPhone.isNotEmpty)
                            pw.Text('Phone: $academyPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'PAID RECEIPT',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1.5, color: PdfColors.blueGrey700),
                  pw.SizedBox(height: 10),

                  // Metadata Grid
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _docMetaRow('Receipt Number:', receipt.receiptNumber, isBold: true),
                          _docMetaRow('Voucher Reference:', voucherNumber),
                          _docMetaRow(
                            'Payment Date:',
                            '${receipt.receiptDate.day}/${receipt.receiptDate.month}/${receipt.receiptDate.year}',
                          ),
                          if (paymentMode != null && paymentMode.isNotEmpty)
                            _docMetaRow('Payment Mode:', PaymentModes.getPdfDisplayName(paymentMode)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _docMetaRow('Student Name:', studentName, isBold: true),
                          if (rollNumber != null && rollNumber.isNotEmpty)
                            _docMetaRow('Roll / Admission No:', rollNumber),
                          if (batchName != null && batchName.isNotEmpty)
                            _docMetaRow('Class / Batch:', batchName),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 18),

                  // Itemized Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Sr.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Amount Received', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('1', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Fee Payment ($voucherNumber)', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(receipt.amount.format(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),

                  // Total Row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text('TOTAL AMOUNT PAID:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.Text(
                              receipt.amount.format(),
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blueGrey900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),

                  // Bottom QR & Signature Section
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.BarcodeWidget(
                            data: receipt.qrData,
                            barcode: pw.Barcode.qrCode(),
                            width: 65,
                            height: 65,
                          ),
                          pw.SizedBox(width: 10),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Official Digital Verification', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Scan QR to verify authentic fee voucher entry', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                              pw.Text('$academyName • Verified Audit Trail', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                            ],
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 130,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700)),
                            ),
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Center(
                              child: pw.Text('Authorized Signature & Stamp', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // 2. Standard 2-Copy School Fee Voucher (A4 Landscape)
  //    (School Copy & Student Copy - Direct Counter Payment, No Bank)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generateFeeVoucherPdf({
    required FeeVoucher voucher,
    required String studentName,
    String? rollNumber,
    required String batchName,
    required String academyName,
    String? academyPhone,
    String? academyAddress,
    String? bankName,
    String? accountTitle,
    String? accountNumber,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        build: (context) {
          final copies = ['SCHOOL COPY', 'STUDENT COPY'];

          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: _buildVoucherCopy(
                  copyTitle: copies[0],
                  voucher: voucher,
                  studentName: studentName,
                  rollNumber: rollNumber,
                  batchName: batchName,
                  academyName: academyName,
                  academyPhone: academyPhone,
                  academyAddress: academyAddress,
                ),
              ),
              // Perforation / Cut line in the center
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                width: 1,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    26,
                    (_) => pw.Container(width: 1, height: 8, color: PdfColors.grey400),
                  ),
                ),
              ),
              pw.Expanded(
                child: _buildVoucherCopy(
                  copyTitle: copies[1],
                  voucher: voucher,
                  studentName: studentName,
                  rollNumber: rollNumber,
                  batchName: batchName,
                  academyName: academyName,
                  academyPhone: academyPhone,
                  academyAddress: academyAddress,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Bulk Vouchers Generator (Each page has one student's 2-copy voucher: School Copy & Student Copy)
  static Future<Uint8List> generateBatchVouchersPdf({
    required List<FeeVoucher> vouchers,
    required Map<int, String> studentNames,
    required Map<int, String> studentRolls,
    required String batchName,
    required String academyName,
    String? academyPhone,
    String? academyAddress,
    String? bankName,
    String? accountTitle,
    String? accountNumber,
  }) async {
    final doc = pw.Document();
    final copies = ['SCHOOL COPY', 'STUDENT COPY'];

    for (final voucher in vouchers) {
      final studentName = studentNames[voucher.studentId] ?? 'Student #${voucher.studentId}';
      final rollNumber = studentRolls[voucher.studentId];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          build: (context) {
            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: _buildVoucherCopy(
                    copyTitle: copies[0],
                    voucher: voucher,
                    studentName: studentName,
                    rollNumber: rollNumber,
                    batchName: batchName,
                    academyName: academyName,
                    academyPhone: academyPhone,
                    academyAddress: academyAddress,
                  ),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      26,
                      (_) => pw.Container(width: 1, height: 8, color: PdfColors.grey400),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: _buildVoucherCopy(
                    copyTitle: copies[1],
                    voucher: voucher,
                    studentName: studentName,
                    rollNumber: rollNumber,
                    batchName: batchName,
                    academyName: academyName,
                    academyPhone: academyPhone,
                    academyAddress: academyAddress,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _buildVoucherCopy({
    required String copyTitle,
    required FeeVoucher voucher,
    required String studentName,
    String? rollNumber,
    required String batchName,
    required String academyName,
    String? academyPhone,
    String? academyAddress,
  }) {
    final lateFeeSurcharge = voucher.lateFee.isZero ? Money.fromRupees(200) : voucher.lateFee;
    final totalAfterDue = voucher.totalDue + lateFeeSurcharge;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Header: School Name & Subtitle
          pw.Center(
            child: pw.Text(
              academyName,
              style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
          ),
          if ((academyAddress != null && academyAddress.isNotEmpty) || (academyPhone != null && academyPhone.isNotEmpty))
            pw.Center(
              child: pw.Text(
                [
                  if (academyAddress != null && academyAddress.isNotEmpty) academyAddress,
                  if (academyPhone != null && academyPhone.isNotEmpty) 'Tel: $academyPhone',
                ].join(' • '),
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
            ),
          pw.SizedBox(height: 3),

          // 2. Banner: Copy Title (SCHOOL COPY / STUDENT COPY)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: copyTitle.contains('SCHOOL') ? PdfColors.blueGrey800 : PdfColors.teal800,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  copyTitle,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  'FEE CHALLAN / VOUCHER',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey200),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),

          // 3. Voucher Meta & Student Information Box (Compact Grid)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: _miniMetaRow('Voucher No:', voucher.voucherNumber, bold: true),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      flex: 4,
                      child: _miniMetaRow('Fee Month:', voucher.monthYear, bold: true),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: _miniMetaRow('Issue Date:', '${voucher.issueDate.day.toString().padLeft(2, '0')}/${voucher.issueDate.month.toString().padLeft(2, '0')}/${voucher.issueDate.year}'),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      flex: 4,
                      child: _miniMetaRow('Due Date:', '${voucher.dueDate.day.toString().padLeft(2, '0')}/${voucher.dueDate.month.toString().padLeft(2, '0')}/${voucher.dueDate.year}', bold: true),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.4, color: PdfColors.grey400, height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: _miniMetaRow('Student Name:', studentName, bold: true),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      flex: 4,
                      child: _miniMetaRow('Roll No:', rollNumber != null && rollNumber.isNotEmpty ? rollNumber : '-'),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _miniMetaRow('Class / Section:', batchName),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),

          // 4. Particulars Table (All dues to submit)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text('Particulars / Head', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text('Amount (PKR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Base Monthly Tuition Fee
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: pw.Text('Monthly Tuition Fee', style: const pw.TextStyle(fontSize: 6.5)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: pw.Text(voucher.baseAmount.format(), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5)),
                  ),
                ],
              ),
              // Previous Arrears
              if (!voucher.carryForward.isZero)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text('Previous Unpaid Arrears', style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text(voucher.carryForward.format(), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              // Concession / Discount
              if (!voucher.discount.isZero)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text('Concession / Discount', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.green900)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text('- ${voucher.discount.format()}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.green900)),
                    ),
                  ],
                ),
              // Payable by Due Date
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text('TOTAL PAYABLE BY DUE DATE', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text(voucher.totalDue.format(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  ),
                ],
              ),
              // Late Fee Fine / Surcharge
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: pw.Text('Late Fee Surcharge (After Due Date)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.red800)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: pw.Text(lateFeeSurcharge.format(), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.red800)),
                  ),
                ],
              ),
              // Payable after Due Date
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text('TOTAL PAYABLE AFTER DUE DATE', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: pw.Text(totalAfterDue.format(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ),
                ],
              ),
              // If already paid some amount
              if (voucher.amountPaid.paisa > 0) ...[
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text('Amount Received / Paid', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.green900)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: pw.Text(voucher.amountPaid.format(), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.green900)),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      child: pw.Text('NET REMAINING BALANCE TO PAY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      child: pw.Text(voucher.balanceRemaining.format(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ),
                  ],
                ),
              ],
            ],
          ),
          pw.Spacer(),

          // 5. Instruction Note
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
            ),
            child: pw.Text(
              'Notice: Please deposit fee dues at the School Accounts Counter on or before the 10th of every month. Keep the Student Copy safely.',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 4),

          // 6. Barcode & Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.BarcodeWidget(
                    data: voucher.voucherNumber,
                    barcode: pw.Barcode.code128(),
                    width: 90,
                    height: 16,
                    drawText: false,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(voucher.voucherNumber, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 100,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 0.6)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 1.5),
                    child: pw.Center(
                      child: pw.Text('Parent / Depositor Sign', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 0.6)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 1.5),
                    child: pw.Center(
                      child: pw.Text('School Accounts / Cashier Stamp', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Staff Salary Payslip (A4 Portrait or A5)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generatePayslipPdf({
    required PayrollRun run,
    required String academyName,
    String? academyPhone,
    String? academyAddress,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final gross = run.baseSalary + run.allowances;
    final totalDeductions = run.deductions + run.advanceRecovery;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          academyName,
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        if (academyAddress != null && academyAddress.isNotEmpty)
                          pw.Text(academyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (academyPhone != null && academyPhone.isNotEmpty)
                          pw.Text('Phone: $academyPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: run.isPaid ? PdfColors.green700 : PdfColors.amber800,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        run.status.toUpperCase(),
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
                pw.Center(
                  child: pw.Text(
                    'STAFF SALARY PAYSLIP - ${run.monthYear}',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                  ),
                ),
                pw.SizedBox(height: 14),

                // Staff Information
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _docMetaRow('Staff Name:', run.staffName, isBold: true),
                        _docMetaRow('Designation:', run.designation),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _docMetaRow('Month / Period:', run.monthYear),
                        if (run.paidAt != null)
                          _docMetaRow(
                            'Disbursed Date:',
                            '${run.paidAt!.day}/${run.paidAt!.month}/${run.paidAt!.year}',
                          ),
                        if (run.paymentMode != null)
                          _docMetaRow('Payment Mode:', PaymentModes.getPdfDisplayName(run.paymentMode)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Earnings & Deductions Tables
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Earnings
                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('EARNINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                              ),
                            ],
                          ),
                          _tableItemRow('Basic Salary', run.baseSalary.format()),
                          _tableItemRow('Allowances', run.allowances.format()),
                          _tableItemRow('Gross Earnings', gross.format(), isBold: true, bgColor: PdfColors.grey100),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Deductions
                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                              ),
                            ],
                          ),
                          _tableItemRow('Standard Deductions', run.deductions.format()),
                          _tableItemRow('Advance Recovery', run.advanceRecovery.format()),
                          _tableItemRow('Total Deductions', totalDeductions.format(), isBold: true, bgColor: PdfColors.grey100),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Net Salary Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'NET PAYABLE SALARY',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.Text(
                        run.netSalary.format(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signatureBox('Staff Member Signature'),
                    _signatureBox('Accountant Signature'),
                    _signatureBox('Principal / Director Stamp'),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'This is an official computer generated salary slip from $academyName.',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // 4. Student ID Card PDF
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generateStudentIdCardPdf({
    required Student student,
    required String academyName,
    String? batchName,
    String? academyPhone,
    String? academyAddress,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: 250,
              height: 380,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                children: [
                  // Card Header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                      borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          academyName,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'STUDENT IDENTITY CARD',
                          style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // Avatar Placeholder
                  pw.Container(
                    width: 75,
                    height: 85,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Center(
                      child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Student Details
                  pw.Text(
                    student.name,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Roll No: ${student.rollNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                  if (batchName != null && batchName.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Class: $batchName', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text('Guardian: ${student.guardianPhone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Spacer(),

                  // Barcode
                  pw.BarcodeWidget(
                    data: student.rollNumber,
                    barcode: pw.Barcode.code128(),
                    width: 140,
                    height: 26,
                    drawText: false,
                  ),
                  pw.SizedBox(height: 10),

                  // Card Footer
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        academyPhone != null && academyPhone.isNotEmpty ? 'Emergency: $academyPhone' : 'Authorized Student Card',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // 5. Student Fee Card / Ledger Card PDF
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generateStudentFeeCardPdf({
    required Student student,
    required String batchName,
    required String academyName,
    required List<FeeVoucher> history,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  academyName,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'STUDENT ANNUAL FEE LEDGER CARD',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _docMetaRow('Student Name:', student.name, isBold: true),
                      _docMetaRow('Roll Number:', student.rollNumber),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _docMetaRow('Class / Batch:', batchName),
                      _docMetaRow('Guardian Phone:', student.guardianPhone),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Fee Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th('Month'),
                      _th('Voucher #'),
                      _th('Due Date'),
                      _th('Total Due', align: pw.TextAlign.right),
                      _th('Paid', align: pw.TextAlign.right),
                      _th('Balance', align: pw.TextAlign.right),
                      _th('Status'),
                    ],
                  ),
                  for (final v in history)
                    pw.TableRow(
                      children: [
                        _td(v.monthYear),
                        _td(v.voucherNumber),
                        _td('${v.dueDate.day}/${v.dueDate.month}/${v.dueDate.year}'),
                        _td(v.totalDue.format(), align: pw.TextAlign.right),
                        _td(v.amountPaid.format(), align: pw.TextAlign.right),
                        _td(v.balanceRemaining.format(), align: pw.TextAlign.right),
                        _td(v.status.name.toUpperCase()),
                      ],
                    ),
                ],
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('Parent / Guardian Sign'),
                  _signatureBox('Accounts Officer Signature'),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Private Helper Builders
  // ---------------------------------------------------------------------------

  static pw.Widget _thermalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static pw.Widget _docMetaRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniMetaRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              maxLines: 1,
              style: pw.TextStyle(fontSize: 6.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _tableItemRow(String label, String amount, {bool isBold = false, PdfColor? bgColor}) {
    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(amount, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );
  }

  static pw.Widget _signatureBox(String title) {
    return pw.Column(
      children: [
        pw.Container(
          width: 140,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700)),
          ),
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Center(
            child: pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _th(String label, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        label,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _td(String val, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        val,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }
}
