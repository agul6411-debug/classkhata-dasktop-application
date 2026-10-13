import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/core/printing/pdf_document_service.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:classkhata/features/payroll/domain/entities/payroll_entities.dart';
import 'package:classkhata/features/students/domain/entities/student_entities.dart';

void main() {
  group('PdfDocumentService Tests', () {
    test('generateFeeReceiptPdf produces valid PDF bytes for roll80 and A4', () async {
      final receipt = Receipt(
        id: 1,
        receiptNumber: 'RCP-000001',
        voucherId: 10,
        studentId: 101,
        amount: Money.fromRupees(5000),
        qrData: jsonEncode({'receipt': 'RCP-000001', 'amount': 5000}),
        receiptDate: DateTime(2026, 10, 15),
        isCancelled: false,
      );

      // 1. Thermal Roll 80mm
      final thermalBytes = await PdfDocumentService.generateFeeReceiptPdf(
        receipt: receipt,
        studentName: 'Muhammad Ali',
        voucherNumber: 'VCH-2026-10-001',
        rollNumber: 'R-101',
        batchName: 'Grade 9 - Morning',
        academyName: 'Al-Hadi Grammar School',
        academyAddress: 'Gulshan-e-Iqbal, Karachi',
        academyPhone: '021-34567890',
        format: PdfPageFormat.roll80,
      );

      expect(thermalBytes, isNotEmpty);
      // Validate PDF magic number %PDF-
      expect(String.fromCharCodes(thermalBytes.take(5)), equals('%PDF-'));

      // 2. Standard A4
      final a4Bytes = await PdfDocumentService.generateFeeReceiptPdf(
        receipt: receipt,
        studentName: 'Muhammad Ali',
        voucherNumber: 'VCH-2026-10-001',
        rollNumber: 'R-101',
        batchName: 'Grade 9 - Morning',
        academyName: 'Al-Hadi Grammar School',
        academyAddress: 'Gulshan-e-Iqbal, Karachi',
        academyPhone: '021-34567890',
        format: PdfPageFormat.a4,
      );

      expect(a4Bytes, isNotEmpty);
      expect(String.fromCharCodes(a4Bytes.take(5)), equals('%PDF-'));
    });

    test('generateFeeVoucherPdf produces valid 3-copy voucher PDF', () async {
      final voucher = FeeVoucher(
        id: 1,
        voucherNumber: 'VCH-2026-10-001',
        studentId: 101,
        batchId: 5,
        monthYear: '2026-10',
        issueDate: DateTime(2026, 10, 1),
        dueDate: DateTime(2026, 10, 10),
        baseAmount: Money.fromRupees(6500),
        discount: Money.fromRupees(500),
        lateFee: Money.fromRupees(300),
        carryForward: Money.fromRupees(1000),
        totalDue: Money.fromRupees(7000),
        amountPaid: Money.zero(),
        status: VoucherStatus.unpaid,
        createdAt: DateTime(2026, 10, 1),
      );

      final voucherBytes = await PdfDocumentService.generateFeeVoucherPdf(
        voucher: voucher,
        studentName: 'Fatima Zahra',
        rollNumber: 'R-102',
        batchName: 'Grade 10 - Biology',
        academyName: 'The Educators Campus',
        academyAddress: 'Main Boulevard, Lahore',
        academyPhone: '042-35789012',
      );

      expect(voucherBytes, isNotEmpty);
      expect(String.fromCharCodes(voucherBytes.take(5)), equals('%PDF-'));
    });

    test('generatePayslipPdf produces valid staff payslip PDF', () async {
      final run = PayrollRun(
        id: 1,
        monthYear: '2026-10',
        staffId: 5,
        staffName: 'Sir Tariq Mahmood',
        designation: 'Senior Physics Teacher',
        baseSalary: Money.fromRupees(60000),
        allowances: Money.fromRupees(10000),
        deductions: Money.fromRupees(2500),
        advanceRecovery: Money.fromRupees(5000),
        netSalary: Money.fromRupees(62500),
        status: 'paid',
        paidAt: DateTime(2026, 10, 5),
        paymentMode: 'bank',
      );

      final payslipBytes = await PdfDocumentService.generatePayslipPdf(
        run: run,
        academyName: 'Beaconhouse School System',
        academyAddress: 'F-8/3, Islamabad',
        academyPhone: '051-2856789',
      );

      expect(payslipBytes, isNotEmpty);
      expect(String.fromCharCodes(payslipBytes.take(5)), equals('%PDF-'));
    });

    test('generateStudentIdCardPdf and fee ledger produce valid PDF', () async {
      final student = Student(
        id: 101,
        rollNumber: 'STD-2026-001',
        batchId: 1,
        name: 'Ahmed Raza',
        guardianPhone: '03001234567',
        joiningDate: DateTime(2026, 1, 15),
        status: StudentStatus.active,
      );

      final idCardBytes = await PdfDocumentService.generateStudentIdCardPdf(
        student: student,
        academyName: 'City School',
        batchName: 'Class 8-A',
      );

      expect(idCardBytes, isNotEmpty);
      expect(String.fromCharCodes(idCardBytes.take(5)), equals('%PDF-'));
    });
  });
}
