/// Offline License Generator for ClassKhata.
///
/// CRITICAL:
/// This tool contains the RSA-2048 PRIVATE KEY.
/// It must NEVER be packaged into the client application binary or repository release.
/// Run this tool locally to generate signed lifetime license keys for customers.
///
/// Usage:
///   dart run tools/generate_license.dart --machine-id CK-XXXX-XXXX-XXXX --academy "The Citizen Academy"
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

void main(List<String> args) {
  String? machineId;
  String academy = 'Licensed Academy';
  String licenseType = 'lifetime';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--machine-id' && i + 1 < args.length) {
      machineId = args[i + 1].trim().toUpperCase();
      i++;
    } else if (args[i] == '--academy' && i + 1 < args.length) {
      academy = args[i + 1].trim();
      i++;
    } else if (args[i] == '--type' && i + 1 < args.length) {
      licenseType = args[i + 1].trim();
      i++;
    }
  }

  if (machineId == null || machineId.isEmpty) {
    stdout.writeln('Error: --machine-id is required.');
    stdout.writeln('Example: dart run tools/generate_license.dart --machine-id CK-4F8A-9B2C-1D3E --academy "Beaconhouse"');
    exit(1);
  }

  final token = generateSignedLicenseKey(
    machineId: machineId,
    academyName: academy,
    licenseType: licenseType,
  );

  stdout.writeln('================================================================');
  stdout.writeln(' CLASSKHATA SIGNED LICENSE KEY (OFFLINE TOKEN)');
  stdout.writeln('================================================================');
  stdout.writeln('Machine ID : $machineId');
  stdout.writeln('Academy    : $academy');
  stdout.writeln('Type       : $licenseType');
  stdout.writeln('Issued At  : ${DateTime.now().toIso8601String()}');
  stdout.writeln('----------------------------------------------------------------');
  stdout.writeln(token);
  stdout.writeln('================================================================');
}

/// Generates a signed license token string using RSA-2048 private key.
String generateSignedLicenseKey({
  required String machineId,
  required String academyName,
  String licenseType = 'lifetime',
}) {
  final payload = {
    'app': 'ClassKhata',
    'version': '1.0',
    'machineId': machineId,
    'academyName': academyName,
    'licenseType': licenseType,
    'issuedAt': DateTime.now().toUtc().toIso8601String(),
    'nonce': 'CK-${DateTime.now().millisecondsSinceEpoch}',
  };

  final payloadJson = jsonEncode(payload);
  final payloadBytes = utf8.encode(payloadJson);
  final payloadB64 = base64Url.encode(payloadBytes);

  // Private key components
  final modulus = BigInt.parse(
    '172170601722477564227049969611655235430998158835538776390797535931590292141634'
    '070140886292509197469450272064969477045956810830530290850342751789049188251247'
    '075684752985672935571631087802922252811238172475880439081694386206456782461889'
    '776492855775432045886909035324946503135792799944946752604146290679125268561473'
    '406758929832766746818170834572737381194939130051451124429085820531465298921599'
    '505620503235712913935581998791960089928834387131444375406830426609994569144820'
    '235231714570437412014420612143994937454573640197828502432603604619982125009112'
    '10537709952358223527289121394191143724599150946398826355403114852764447',
  );
  final privateExponent = BigInt.parse(
    '782342877961362568119008818687930926214981639397949976489303846688551337409076'
    '187313364021991226427854357400367887823457562374413241607520507236810477458861'
    '088223742910621484249076673447216791845625032627633165365039416089885558038219'
    '256901787538698189803035090403422015561272194693152614942929419476685002011051'
    '536779199505113406790525934228435514970230922670818058111647052448560701802342'
    '033379774677407098143559426385453128513940612976923326976960327870447516038734'
    '260080010384934491523858114210127747758434755815614001124934141878135107894930'
    '9997364375618863766790530281328825568622996717230369149575830369946113',
  );
  final p = BigInt.parse(
    '170523917454977784838670973768375162767108779643952235580034776945039145463113'
    '347099618539157086275794149449261755454281243290079888792915235028574197027268'
    '192297843300100592505571421930150091776100103608840363920576837999839048049758'
    '499982172291416779063261849204456114136972868505299546222296067137772188383',
  );
  final q = BigInt.parse(
    '100965661762922225678408146640081597546449060802303723030368352250554524464121'
    '317857712614493203205998658430225558942326341919636389081804733088295114881339'
    '160603046270402590439199194379139865426777373722072673498238710873431456764298'
    '452164252011245957485494313288897531431154321467142583742307967568922243009',
  );

  final privKey = RSAPrivateKey(modulus, privateExponent, p, q);
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privKey));

  final signature = signer.generateSignature(Uint8List.fromList(payloadBytes));
  final signatureB64 = base64Url.encode(signature.bytes);

  return '$payloadB64.$signatureB64';
}
