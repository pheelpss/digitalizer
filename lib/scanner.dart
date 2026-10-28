import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'domain.dart';
import 'vision.dart';

class OfflineOcrException implements Exception {
  const OfflineOcrException(this.diagnostic);
  final String diagnostic;
  @override
  String toString() => 'Falha no leitor offline do Android.';
}

class ScanLayout {
  ScanLayout(this.detectedAreas, this.anchors, this.headerX);
  final List<String> detectedAreas;
  final List<Map<String, dynamic>> anchors;
  final double? headerX;
}

class Scanner {
  Future<ScanLayout> inspect(Uint8List bytes, Catalog catalog) async {
    final directory = await getTemporaryDirectory();
    final folder = Directory('${directory.path}/digitalizer-session');
    await folder.create(recursive: true);
    final file = File('${folder.path}/page.png');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final lines = recognized.blocks.expand((block) => block.lines).toList();
      final header = lines
          .where((line) => line.boundingBox.center.dy < 2263 * .23)
          .map((line) => line.text)
          .join(' ');
      final anchors = <Map<String, dynamic>>[];
      double? headerX;
      for (final line in lines) {
        final number = questionNumber(line.text);
        if (number != null && line.boundingBox.left < 1600 * .22) {
          anchors.add({'number': number, 'y': line.boundingBox.center.dy});
        }
        final text = normalize(line.text).replaceAll(RegExp(r'[^a-z]'), '');
        if (text.contains('mesatual') && !text.contains('mesant')) {
          headerX ??= line.boundingBox.center.dx;
        }
      }
      return ScanLayout(catalog.detectAreas(header), anchors, headerX);
    } on PlatformException catch (error, stack) {
      throw OfflineOcrException(
        'Digitalizer 0.1.1+2\n'
        'Etapa: OCR de texto impresso / ML Kit Latin\n'
        'Imagem normalizada: PNG 1600x2263, ${bytes.length} bytes\n'
        'Build: minificação e redução de recursos nativos desativadas\n'
        '$error\n$stack',
      );
    } finally {
      try {
        await recognizer.close();
      } on PlatformException {
        // Uma falha ao encerrar não deve substituir o erro original do leitor.
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<Map<String, dynamic>> recognize(
    Uint8List bytes,
    Uint8List model,
    ScanLayout layout,
  ) => compute(readCells, {
    'bytes': bytes,
    'model': model,
    'anchors': layout.anchors,
    'headerX': layout.headerX,
  });
}
