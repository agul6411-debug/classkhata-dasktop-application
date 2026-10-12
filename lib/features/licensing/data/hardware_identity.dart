/// Generates a stable hardware identifier (Machine ID) for offline licensing.
library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class HardwareIdentity {
  HardwareIdentity._();

  /// Returns a stable, hashed Machine ID for this computer in the format `CK-XXXX-XXXX-XXXX`.
  /// An optional [mockSeed] can be provided for deterministic unit testing.
  static String getMachineId({String? mockSeed}) {
    if (mockSeed != null) {
      final digest = sha256.convert(utf8.encode(mockSeed)).toString().toUpperCase();
      return 'CK-${digest.substring(0, 4)}-${digest.substring(4, 8)}-${digest.substring(8, 12)}';
    }

    final buffer = StringBuffer();

    // Pull stable Windows system environment variables
    buffer.write(Platform.environment['COMPUTERNAME'] ?? 'LOCAL-PC');
    buffer.write('|');
    buffer.write(Platform.environment['PROCESSOR_IDENTIFIER'] ?? 'GENERIC-CPU');
    buffer.write('|');
    buffer.write(Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64');
    buffer.write('|');
    buffer.write(Platform.environment['NUMBER_OF_PROCESSORS'] ?? '4');
    buffer.write('|');
    buffer.write(Platform.environment['SystemDrive'] ?? 'C:');

    final raw = buffer.toString();
    final digest = sha256.convert(utf8.encode(raw)).toString().toUpperCase();

    // Format as CK-XXXX-XXXX-XXXX
    return 'CK-${digest.substring(0, 4)}-${digest.substring(4, 8)}-${digest.substring(8, 12)}';
  }
}
