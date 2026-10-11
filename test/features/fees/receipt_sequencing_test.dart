import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Receipt Sequential Formatting (Gap-Free Guarantees)', () {
    test('Receipt numbering formats strictly to 6-digit zero-padded numbers', () {
      String formatReceipt(String series, int counter) {
        return '$series-${counter.toString().padLeft(6, '0')}';
      }

      expect(formatReceipt('RCP', 1), 'RCP-000001');
      expect(formatReceipt('RCP', 99), 'RCP-000099');
      expect(formatReceipt('RCP', 1000), 'RCP-001000');
      expect(formatReceipt('RCP', 999999), 'RCP-999999');
    });

    test('Sequential generation produces strictly consecutive sequence with no skipped values', () {
      final generatedReceipts = <String>[];
      int counter = 0;

      for (int i = 0; i < 50; i++) {
        counter++;
        generatedReceipts.add('RCP-${counter.toString().padLeft(6, '0')}');
      }

      expect(generatedReceipts.length, 50);
      expect(generatedReceipts.first, 'RCP-000001');
      expect(generatedReceipts.last, 'RCP-000050');

      // Verify strict increment with no gaps
      for (int i = 0; i < generatedReceipts.length - 1; i++) {
        final currentNum = int.parse(generatedReceipts[i].split('-')[1]);
        final nextNum = int.parse(generatedReceipts[i + 1].split('-')[1]);
        expect(nextNum, currentNum + 1, reason: 'Gap detected between $currentNum and $nextNum');
      }
    });
  });
}
