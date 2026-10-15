import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/services/receipt_image_service.dart';

void main() {
  group('ReceiptImageService Tests', () {
    test('normalizes standard 03xx Pakistani numbers', () {
      expect(
        ReceiptImageService.normalizePakistaniPhone('03001234567'),
        equals('923001234567'),
      );
      expect(
        ReceiptImageService.normalizePakistaniPhone('0321-9876543'),
        equals('923219876543'),
      );
    });

    test('normalizes +92 or 92 prefixed numbers', () {
      expect(
        ReceiptImageService.normalizePakistaniPhone('+923331122334'),
        equals('923331122334'),
      );
      expect(
        ReceiptImageService.normalizePakistaniPhone('923455566778'),
        equals('923455566778'),
      );
    });

    test('handles formatted numbers with spaces and brackets', () {
      expect(
        ReceiptImageService.normalizePakistaniPhone('(0312) 345 6789'),
        equals('923123456789'),
      );
    });
  });
}
