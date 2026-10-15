import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:classkhata/features/fees/presentation/widgets/receipt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReceiptDialog displays receipt details and WhatsApp Picture button', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final receipt = Receipt(
      id: 1,
      receiptNumber: 'RCP-202610-0001',
      voucherId: 101,
      studentId: 201,
      amount: const Money.fromPaisa(500000), // Rs. 5,000
      qrData: 'CLASSTABLE:VERIFY:RCP-202610-0001',
      receiptDate: DateTime(2026, 10, 14),
      isCancelled: false,
    );

    final voucher = FeeVoucher(
      id: 101,
      voucherNumber: 'VCH-202610-0001',
      studentId: 201,
      batchId: 1,
      monthYear: '2026-10',
      issueDate: DateTime(2026, 10, 1),
      dueDate: DateTime(2026, 10, 15),
      baseAmount: const Money.fromPaisa(500000),
      discount: const Money.zero(),
      lateFee: const Money.zero(),
      carryForward: const Money.zero(),
      totalDue: const Money.fromPaisa(500000),
      amountPaid: const Money.fromPaisa(500000),
      status: VoucherStatus.paid,
      createdAt: DateTime(2026, 10, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => ReceiptDialog(
                    receipt: receipt,
                    voucher: voucher,
                    studentName: 'Ali Ahmed',
                    guardianPhone: '03001234567',
                    voucherNumber: 'VCH-202610-0001',
                    batchName: 'Class 9',
                    rollNumber: 'STD-0042',
                  ),
                );
              },
              child: const Text('Open Receipt'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Receipt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify key fields
    expect(find.text('Ali Ahmed'), findsOneWidget);
    expect(find.text('STD-0042'), findsOneWidget);
    expect(find.text('VCH-202610-0001'), findsWidgets);
    expect(find.text('RCP-202610-0001'), findsOneWidget);
    expect(find.text('Send WhatsApp Picture'), findsOneWidget);
    expect(find.text('Print Slip'), findsOneWidget);
  });
}
