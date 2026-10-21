/// Centralized PDF generation service for ClassKhata.
/// Generates official Fee Receipts, 3-copy Fee Vouchers, Salary Payslips,
/// Student ID Cards, and Fee Cards for printing and print preview.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/fees/domain/entities/fee_entities.dart';
import '../../features/payroll/domain/entities/payroll_entities.dart';
import '../../features/payroll/domain/entities/staff_profile.dart';
import '../../features/payroll/domain/services/staff_profile_service.dart';
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
                  // Bottom Note & Signature Section
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Official Fee Receipt / Voucher', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('$academyName • Verified Record', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 140,
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
                      child: pw.Text(voucher.carryForward.format(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('Ref: ${voucher.voucherNumber}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.SizedBox(height: 14),
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

  // ---------------------------------------------------------------------------
  // 6. Staff Employment & Registration Dossier (2 Pages: Bio-data + Terms)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> generateStaffJoiningDossierPdf({
    required StaffMember staff,
    required StaffProfile profile,
    required String academyName,
    String? academyTagline,
    String? academyPhone,
    String? academyAddress,
    String? logoPath,
    String? schoolTerms,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();

    Uint8List? logoBytes;
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final f = File(logoPath);
        if (f.existsSync()) {
          logoBytes = await f.readAsBytes();
        }
      } catch (_) {}
    }

    Uint8List? photoBytes;
    if (profile.photoPath != null && profile.photoPath!.isNotEmpty) {
      try {
        final f = File(profile.photoPath!);
        if (f.existsSync()) {
          photoBytes = await f.readAsBytes();
        }
      } catch (_) {}
    }

    // -------------------------------------------------------------------------
    // PAGE 1: STAFF RECRUITMENT & PERSONAL DOSSIER
    // -------------------------------------------------------------------------
    final depositAmount = profile.securityDepositAmount > 0
        ? profile.securityDepositAmount
        : profile.basicSalary;
    final depositText = profile.securityDepositRequired
        ? 'YES (Rs. $depositAmount Held in Deposit)'
        : 'NO (Exempted)';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          academyName,
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        if (academyTagline != null && academyTagline.isNotEmpty)
                          pw.Text(academyTagline, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        if (academyAddress != null && academyAddress.isNotEmpty)
                          pw.Text(academyAddress, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                        if (academyPhone != null && academyPhone.isNotEmpty)
                          pw.Text('Tel: $academyPhone', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey800),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('STAFF CODE: ${staff.staffCode}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                        pw.SizedBox(height: 2),
                        pw.Text('Joined: ${staff.joiningDate.day}/${staff.joiningDate.month}/${staff.joiningDate.year}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.Text('Role: ${staff.designation}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Title Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                child: pw.Center(
                  child: pw.Text(
                    'STAFF EMPLOYMENT & REGISTRATION DOSSIER',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.8),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // Section 1: Bio-Data & Photo Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bio-Data Table (4 columns)
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.1),
                        1: pw.FlexColumnWidth(1.9),
                        2: pw.FlexColumnWidth(1.1),
                        3: pw.FlexColumnWidth(1.9),
                      },
                      children: [
                        pw.TableRow(children: [
                          _dossierCell('Full Name:', bold: true),
                          _dossierCell(staff.name, highlight: true),
                          _dossierCell('Father / Husband:', bold: true),
                          _dossierCell(profile.fatherOrHusbandName ?? '-'),
                        ]),
                        pw.TableRow(children: [
                          _dossierCell('CNIC / B-Form:', bold: true),
                          _dossierCell(staff.cnic ?? '-'),
                          _dossierCell('Gender / Status:', bold: true),
                          _dossierCell('${profile.gender} / ${profile.maritalStatus}'),
                        ]),
                        pw.TableRow(children: [
                          _dossierCell('Date of Birth:', bold: true),
                          _dossierCell(profile.dob ?? '-'),
                          _dossierCell('Calculated Age:', bold: true),
                          _dossierCell(profile.calculatedAge, highlight: true),
                        ]),
                        pw.TableRow(children: [
                          _dossierCell('Blood Group:', bold: true),
                          _dossierCell(profile.bloodGroup ?? '-'),
                          _dossierCell('Religion / Nation:', bold: true),
                          _dossierCell('${profile.religion} / ${profile.nationality}'),
                        ]),
                        pw.TableRow(children: [
                          _dossierCell('Domicile District:', bold: true),
                          _dossierCell(profile.domicile ?? '-'),
                          _dossierCell('Employment Nature:', bold: true),
                          _dossierCell(profile.employmentType),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Photo Box
                  pw.Container(
                    width: 75,
                    height: 94,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      color: PdfColors.grey100,
                    ),
                    child: photoBytes != null
                        ? pw.ClipRRect(
                            horizontalRadius: 3,
                            verticalRadius: 3,
                            child: pw.Image(pw.MemoryImage(photoBytes), fit: pw.BoxFit.cover),
                          )
                        : pw.Center(
                            child: pw.Text(
                              'AFFIX\nRECENT\nPASSPORT\nPHOTO',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                            ),
                          ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // Section 2: Contact & Residential Details
              _dossierSectionHeading('CONTACT & RESIDENTIAL INFORMATION'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.3),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(2.3),
                },
                children: [
                  pw.TableRow(children: [
                    _dossierCell('Mobile / WhatsApp:', bold: true),
                    _dossierCell(staff.phone, highlight: true),
                    _dossierCell('Home / Tel:', bold: true),
                    _dossierCell(profile.homePhone ?? '-'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Email Address:', bold: true),
                    _dossierCell(profile.email ?? '-'),
                    _dossierCell('Emergency Contact:', bold: true),
                    _dossierCell(profile.emergencyContactName != null && profile.emergencyContactName!.isNotEmpty
                        ? '${profile.emergencyContactName} (${profile.emergencyContactPhone ?? "-"})'
                        : '-'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Current Address:', bold: true),
                    _dossierCell(profile.currentAddress ?? '-'),
                    _dossierCell('Permanent Address:', bold: true),
                    _dossierCell(profile.permanentAddress ?? '-'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 5),

              // Section 3: Academic Qualifications & Teaching Specialization
              _dossierSectionHeading('ACADEMIC QUALIFICATIONS & TEACHING SPECIALIZATION'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.3),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(2.3),
                },
                children: [
                  pw.TableRow(children: [
                    _dossierCell('Highest Degree:', bold: true),
                    _dossierCell(profile.highestQualification ?? '-'),
                    _dossierCell('Institute / Board:', bold: true),
                    _dossierCell(profile.institute ?? '-'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Passing Year:', bold: true),
                    _dossierCell(profile.passingYear ?? '-'),
                    _dossierCell('Prof. Training:', bold: true),
                    _dossierCell(profile.professionalTraining ?? 'None'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Subject Specialist:', bold: true),
                    _dossierCell(profile.subjectSpecialist ?? 'General Teaching', highlight: true),
                    _dossierCell('Assigned Classes:', bold: true),
                    _dossierCell(profile.assignedClasses ?? 'All Grades / Sections'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Total Experience:', bold: true),
                    _dossierCell(profile.experienceYears != null && profile.experienceYears!.isNotEmpty ? '${profile.experienceYears} Years' : '-'),
                    _dossierCell('Previous School:', bold: true),
                    _dossierCell(profile.previousInstitute ?? '-'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 5),

              // Section 4: Remuneration, Bank & 1-Month Salary Security Deposit Policy
              _dossierSectionHeading('REMUNERATION, BANK ACCOUNT & 1-MONTH SALARY SECURITY DEPOSIT'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.3),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(1.3),
                  3: pw.FlexColumnWidth(2.2),
                },
                children: [
                  pw.TableRow(children: [
                    _dossierCell('Basic Pay (Monthly):', bold: true),
                    _dossierCell('Rs. ${profile.basicSalary}'),
                    _dossierCell('Allowances / Net:', bold: true),
                    _dossierCell('Rs. ${profile.allowances} (Gross: Rs. ${profile.grossPackage})', highlight: true),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('1-Month Deposit:', bold: true),
                    _dossierCell(depositText, highlight: true),
                    _dossierCell('Deposit Terms:', bold: true),
                    _dossierCell(profile.securityDepositTerms),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Salary Bank A/C:', bold: true),
                    _dossierCell(profile.bankName != null && profile.bankName!.isNotEmpty
                        ? '${profile.bankName} - ${profile.bankAccountNumber ?? "-"}'
                        : 'Cash Payment / Not Provided'),
                    _dossierCell('Account Title:', bold: true),
                    _dossierCell(profile.bankAccountTitle ?? staff.name),
                  ]),
                ],
              ),
              pw.SizedBox(height: 5),

              // Section 5: References & Official Verification Checklist
              _dossierSectionHeading('OFFICIAL REFERENCES & SUBMITTED DOCUMENTS VERIFICATION'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.3),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(1.3),
                  3: pw.FlexColumnWidth(2.2),
                },
                children: [
                  pw.TableRow(children: [
                    _dossierCell('Reference 1 (Guarantor):', bold: true),
                    _dossierCell(profile.reference1Name != null && profile.reference1Name!.isNotEmpty
                        ? '${profile.reference1Name} (${profile.reference1Relation ?? "-"})'
                        : '-'),
                    _dossierCell('Ref 1 Contact:', bold: true),
                    _dossierCell(profile.reference1Phone ?? '-'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Reference 2 (Guarantor):', bold: true),
                    _dossierCell(profile.reference2Name != null && profile.reference2Name!.isNotEmpty
                        ? '${profile.reference2Name} (${profile.reference2Relation ?? "-"})'
                        : '-'),
                    _dossierCell('Ref 2 Contact:', bold: true),
                    _dossierCell(profile.reference2Phone ?? '-'),
                  ]),
                  pw.TableRow(children: [
                    _dossierCell('Documents Submitted:', bold: true),
                    _dossierCell(profile.documentsSubmitted ?? 'CNIC Copy, Educational Degrees, 2 Photos Verified'),
                    _dossierCell('Official Verification:', bold: true),
                    _dossierCell('Verified by HR / In-charge'),
                  ]),
                ],
              ),
              pw.SizedBox(height: 8),

              // Official Document Footer (Page 1)
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Official Confidential Staff Record - $academyName', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('Page 1 of 2  [ Turn over for Terms & Conditions and Agreement ]', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // -------------------------------------------------------------------------
    // PAGE 2: TERMS OF EMPLOYMENT & CODE OF CONDUCT AGREEMENT
    // -------------------------------------------------------------------------
    final effectiveTerms = (schoolTerms != null && schoolTerms.trim().isNotEmpty)
        ? schoolTerms.trim()
        : StaffProfileService.defaultTerms;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 40,
                      height: 40,
                      margin: const pw.EdgeInsets.only(right: 10),
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          academyName,
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        pw.Text(
                          'TERMS OF EMPLOYMENT & CODE OF CONDUCT AGREEMENT',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Text('Page 2 of 2', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // Staff Details Strip
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Employee: ${staff.name}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Staff ID: ${staff.staffCode}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Designation: ${staff.designation}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('CNIC: ${staff.cnic ?? "-"}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Terms & Conditions Body (School's Custom Terms)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  effectiveTerms,
                  style: const pw.TextStyle(fontSize: 7.3, color: PdfColors.grey900, lineSpacing: 1.4),
                ),
              ),
              pw.SizedBox(height: 8),

              // Employee Declaration Statement
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey400, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EMPLOYEE SOLEMN UNDERTAKING & DECLARATION',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'I, ${staff.name}, hereby solemnly declare that all particulars stated in this registration dossier are true, complete, and authentic. I have carefully read, understood, and unconditionally accepted all the employment terms, responsibilities, leave rules, 1-month salary security deposit policy, and code of conduct set forth above by $academyName. I solemnly pledge to perform my educational duties with the highest standard of dedication, integrity, and institutional discipline.',
                      style: pw.TextStyle(fontSize: 7.2, fontStyle: pw.FontStyle.italic, color: PdfColors.grey900, lineSpacing: 1.3),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Signatures & Stamps
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 145,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey800, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Column(
                          children: [
                            pw.Text('Employee Signature & Thumb', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('Date: _______________', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 145,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey800, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Column(
                          children: [
                            pw.Text('Principal / Head of Institution', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('Official Stamp & Signature', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 145,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey800, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Column(
                          children: [
                            pw.Text('Managing Director / Chairman', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('Authorized Signature & Seal', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Center(
                child: pw.Text(
                  'ClassKhata Verified Official Agreement - Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _dossierSectionHeading(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
      ),
    );
  }

  static pw.Widget _dossierCell(
    String text, {
    bool bold = false,
    bool highlight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      color: bold ? PdfColors.grey50 : null,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: (bold || highlight) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: highlight ? PdfColors.blueGrey900 : (bold ? PdfColors.grey800 : PdfColors.black),
        ),
      ),
    );
  }
}
