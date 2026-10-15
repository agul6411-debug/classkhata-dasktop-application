/// Service for saving receipt images, copying to Windows clipboard,
/// and sharing via WhatsApp and Windows File Explorer.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceiptImageService {
  ReceiptImageService._();

  /// Normalizes Pakistani phone numbers to international format (e.g. 923001234567).
  static String normalizePakistaniPhone(String rawPhone) {
    final clean = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('03')) {
      return '92${clean.substring(1)}';
    } else if (clean.startsWith('0')) {
      return '92${clean.substring(1)}';
    } else if (clean.startsWith('92')) {
      return clean;
    }
    return clean;
  }

  /// Saves receipt PNG bytes into the Documents/ClassKhata/Receipts directory.
  static Future<File> saveReceiptImage({
    required Uint8List pngBytes,
    required String receiptNumber,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final sanitizedReceiptNo = receiptNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final folder = Directory(p.join(docDir.path, 'ClassKhata', 'Receipts'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final filePath = p.join(folder.path, 'Receipt_$sanitizedReceiptNo.png');
    final file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  /// Copies an image file to the Windows Clipboard as both a FileDrop and a Bitmap.
  /// When the user presses Ctrl+V in WhatsApp, WhatsApp immediately attaches the picture.
  static Future<bool> copyImageToWindowsClipboard(String filePath) async {
    if (!Platform.isWindows) return false;
    try {
      final normalizedPath = filePath.replaceAll('/', '\\');
      final script = '''
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
[System.Windows.Forms.Clipboard]::Clear()
Set-Clipboard -Path "$normalizedPath"
\$img = [System.Drawing.Image]::FromFile("$normalizedPath")
[System.Windows.Forms.Clipboard]::SetImage(\$img)
''';

      // Encode script in UTF-16LE base64 for PowerShell -EncodedCommand (prevents any escaping issues)
      final utf16leBytes = Uint8List(script.length * 2);
      final byteData = ByteData.sublistView(utf16leBytes);
      for (int i = 0; i < script.length; i++) {
        byteData.setUint16(i * 2, script.codeUnitAt(i), Endian.little);
      }
      final encodedCommand = base64Encode(utf16leBytes);

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-EncodedCommand',
        encodedCommand,
      ]);

      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error copying receipt image to Windows clipboard: $e');
      return false;
    }
  }

  /// Highlights and opens the receipt image in Windows File Explorer.
  static Future<void> openFileInExplorer(String filePath) async {
    if (!Platform.isWindows) return;
    try {
      final normalizedPath = filePath.replaceAll('/', '\\');
      await Process.run('explorer.exe', ['/select,', normalizedPath]);
    } catch (e) {
      debugPrint('Error launching explorer: $e');
    }
  }

  /// Opens the WhatsApp chat with the parent.
  static Future<bool> openWhatsAppChat({
    required String phone,
    String? message,
  }) async {
    final formattedPhone = normalizePakistaniPhone(phone);
    final query = message != null && message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : '';
    final uri = Uri.parse('https://wa.me/$formattedPhone$query');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
