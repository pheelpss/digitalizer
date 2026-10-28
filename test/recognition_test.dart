import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:digitalizer/domain.dart';
import 'package:digitalizer/digit_model.dart';
import 'package:digitalizer/vision.dart';

void main() {
  late Catalog catalog;
  late Uint8List bytes;
  setUpAll(() {
    catalog = Catalog.parse(File('assets/catalog.json').readAsStringSync());
    bytes = File('assets/digits.bin').readAsBytesSync();
  });
  test('catálogo é o das 32 áreas e 749 perguntas, com Showroom', () {
    expect(catalog.areas.length, 32);
    expect(catalog.areas.values.fold<int>(0, (n, q) => n + q.length), 749);
    expect(catalog.areas['Showroom']!.length, 14);
    expect(catalog.areas['Showroom']!.last.number, '5.2');
  });
  test('área reconhecida com acentos, sem casar pedaços de palavras', () {
    expect(catalog.detectAreas('Área/Seção Auditada LEVES Mês de referência'), [
      'Leves',
    ]);
    expect(catalog.detectAreas('Área/Seção Auditada MANUTENÇÃO ADM'), [
      'Manutenção ADM',
    ]);
    expect(catalog.detectAreas('clareza sobre a área'), isEmpty);
  });
  test(
    'questionário antigo, linha ausente ou duplicada bloqueia aplicação',
    () {
      final numbers = catalog.areas['Leves']!.map((q) => q.number).toList();
      expect(catalog.matches('Leves', numbers), isTrue);
      expect(catalog.matches('Leves', numbers.take(24)), isFalse);
      expect(catalog.matches('Leves', [...numbers, numbers.first]), isFalse);
      expect(catalog.matches('Showroom', numbers), isFalse);
    },
  );
  test('número da pergunta vem da margem, não do texto no meio da linha', () {
    expect(questionNumber('1.2 EXISTE MATERIAL'), '1.2');
    expect(questionNumber(' 5, 2 CARTAZES'), '5.2');
    expect(questionNumber('RESULTADO 1S'), isNull);
    expect(questionNumber('MÉDIA: 4.00'), isNull);
  });
  test('zero é válido, seis e baixa confiança não são notas', () {
    expect(const DigitPrediction(0, .99, .98).accepted, 0);
    expect(const DigitPrediction(6, .99, .98).accepted, isNull);
    expect(const DigitPrediction(4, .90, .85).accepted, isNull);
    expect(const DigitPrediction(3, .98, .50).accepted, isNull);
  });
  test('modelo embarcado executa inferência, rejeita arquivo truncado', () {
    final model = DigitModel(bytes);
    expect(model.inputs, 784);
    expect(
      model.predict(List<double>.filled(784, 0)).digit,
      inInclusiveRange(0, 9),
    );
    expect(() => DigitModel(Uint8List(16)), throwsFormatException);
    expect(() => DigitModel(Uint8List(3)), throwsFormatException);
  });
  test('célula vazia não vira zero e dois componentes não viram nota', () {
    final model = DigitModel(bytes);
    final image = img.Image(width: 100, height: 60)
      ..clear(img.ColorRgb8(255, 255, 255));
    expect(classifyCell(image, [0, 0, 100, 60], 150, model)['score'], isNull);
    for (var y = 12; y < 45; y++) {
      for (final x in [25, 26, 65, 66]) {
        image.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
    final result = classifyCell(image, [0, 0, 100, 60], 150, model);
    expect(result['score'], isNull);
    expect(result['reason'], contains('Mais de um'));
  });
  test('sem bordas de tabela nenhuma coluna é inventada', () {
    final image = img.Image(width: 1600, height: 2263)
      ..clear(img.ColorRgb8(255, 255, 255));
    final result = readCells({
      'bytes': Uint8List.fromList(img.encodePng(image)),
      'model': bytes,
      'anchors': <Map<String, dynamic>>[
        {'number': '1.1', 'y': 300.0},
      ],
      'headerX': null,
    });
    expect(result['error'], isNotNull);
  });
  test('coluna do mês anterior não é usada quando cabeçalho atual diverge', () {
    final image = img.Image(width: 1600, height: 2263)
      ..clear(img.ColorRgb8(255, 255, 255));
    for (var y = 200; y < 700; y++) {
      for (final x in [1000, 1250, 1510]) {
        image.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
    final result = readCells({
      'bytes': Uint8List.fromList(img.encodePng(image)),
      'model': bytes,
      'anchors': <Map<String, dynamic>>[
        {'number': '1.1', 'y': 250.0},
        {'number': '1.2', 'y': 650.0},
      ],
      'headerX': 1100.0,
    });
    expect(result['error'], contains('MÊS ATUAL'));
  });
}
