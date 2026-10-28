import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'digit_model.dart';

// Executadas em isolate: nenhum acesso à rede ou armazenamento permanente.
Uint8List rectifyPhoto(Map<String, dynamic> request) {
  final source = img.decodeImage(request['bytes'] as Uint8List);
  if (source == null) {
    throw const FormatException('Não foi possível abrir a foto.');
  }
  final image = img.bakeOrientation(source);
  final points = request['points'] as List<List<double>>;
  img.Point point(int i) => img.Point(
    points[i][0] * (image.width - 1),
    points[i][1] * (image.height - 1),
  );
  final output = img.copyRectify(
    image,
    topLeft: point(0),
    topRight: point(1),
    bottomRight: point(2),
    bottomLeft: point(3),
    toImage: img.Image(width: 1600, height: 2263),
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodePng(output));
}

List<int> groupPeaks(List<int> counts, double threshold) {
  final peaks = <int>[];
  int? start;
  for (var i = 0; i <= counts.length; i++) {
    if (i < counts.length && counts[i] >= threshold) {
      start ??= i;
    } else if (start != null) {
      peaks.add((start + i - 1) ~/ 2);
      start = null;
    }
  }
  return peaks;
}

double luminance(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return .299 * pixel.r + .587 * pixel.g + .114 * pixel.b;
}

Map<String, dynamic> readCells(Map<String, dynamic> request) {
  final image = img.decodePng(request['bytes'] as Uint8List)!;
  final model = DigitModel(request['model'] as Uint8List);
  final anchors = (request['anchors'] as List<Map<String, dynamic>>).toList()
    ..sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));
  if (anchors.isEmpty) return {'error': 'Nenhuma pergunta localizada.'};
  final w = image.width, h = image.height;
  final top = math.max(0, (anchors.first['y'] as double).floor() - 25);
  final bottom = math.min(h - 1, (anchors.last['y'] as double).ceil() + 25);
  final vertical = List<int>.filled(w, 0);
  final horizontal = List<int>.filled(h, 0);
  for (var y = top; y <= bottom; y++) {
    for (var x = (w * .04).floor(); x < w * .97; x++) {
      if (luminance(image, x, y) < 155) {
        vertical[x]++;
        horizontal[y]++;
      }
    }
  }
  final columns = groupPeaks(
    vertical,
    (bottom - top) * .48,
  ).where((x) => x > w * .55).toList();
  if (columns.length < 2) {
    return {
      'error':
          'As bordas da coluna de notas não ficaram nítidas. Refaça o enquadramento.',
    };
  }
  final left = columns[columns.length - 2], right = columns.last;
  if (right - left < 25 || right - left > w * .20) {
    return {
      'error': 'Não foi possível separar a coluna atual da coluna anterior.',
    };
  }
  final headerX = request['headerX'] as double?;
  if (headerX != null && (headerX < left || headerX > right)) {
    return {
      'error':
          'O cabeçalho MÊS ATUAL não coincide com a coluna localizada. Refaça a captura.',
    };
  }
  final borders = groupPeaks(horizontal, w * .52);
  final readings = <Map<String, dynamic>>[];
  for (final anchor in anchors) {
    final y = anchor['y'] as double;
    final above = borders.where((b) => b < y).toList();
    final below = borders.where((b) => b > y).toList();
    if (above.isEmpty || below.isEmpty || below.first - above.last > h * .065) {
      readings.add({
        'number': anchor['number'],
        'score': null,
        'reason': 'Limites da linha não identificados.',
      });
      continue;
    }
    final rect = [left + 5, above.last + 4, right - 5, below.first - 4];
    if (rect[3] - rect[1] < 6) {
      readings.add({
        'number': anchor['number'],
        'score': null,
        'reason': 'Linha estreita ou ilegível.',
      });
      continue;
    }
    final decisions = [
      for (final threshold in [110.0, 145.0, 180.0])
        classifyCell(image, rect, threshold, model),
    ];
    final first = decisions.first;
    final score = first['score'];
    final stable = score != null && decisions.every((r) => r['score'] == score);
    readings.add({
      'number': anchor['number'],
      'score': stable ? score : null,
      'reason': stable
          ? 'Sugestão estável; confira na foto.'
          : (first['reason'] ?? 'Leitura ambígua entre versões da imagem.'),
      'confidence': first['confidence'],
      'rect': rect,
    });
  }
  return {
    'readings': readings,
    'column': [left, right],
  };
}

Map<String, dynamic> classifyCell(
  img.Image image,
  List<int> rect,
  double threshold,
  DigitModel model,
) {
  final width = rect[2] - rect[0], height = rect[3] - rect[1];
  final mask = List<int>.filled(width * height, 0);
  var ink = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (luminance(image, rect[0] + x, rect[1] + y) < threshold) {
        mask[y * width + x] = 1;
        ink++;
      }
    }
  }
  if (ink < 5 || ink / mask.length < .002) {
    return {'score': null, 'reason': 'Célula vazia ou traço insuficiente.'};
  }
  if (ink / mask.length > .30) {
    return {
      'score': null,
      'reason': 'Excesso de tinta, sombra ou possível rasura.',
    };
  }
  // Componentes separados: duas escritas na célula não viram uma nota só.
  final visited = List<bool>.filled(mask.length, false);
  final components = <List<int>>[];
  for (var index = 0; index < mask.length; index++) {
    if (mask[index] == 0 || visited[index]) continue;
    final queue = <int>[index];
    visited[index] = true;
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final i = queue[cursor], x = i % width, y = i ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final n = ny * width + nx;
          if (mask[n] == 1 && !visited[n]) {
            visited[n] = true;
            queue.add(n);
          }
        }
      }
    }
    if (queue.length >= math.max(4, ink * .06)) components.add(queue);
  }
  if (components.length != 1) {
    return {
      'score': null,
      'reason': 'Mais de um traço separado; possível correção ou rasura.',
    };
  }
  final pixels = components.single;
  final xs = pixels.map((i) => i % width), ys = pixels.map((i) => i ~/ width);
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final bw = maxX - minX + 1, bh = maxY - minY + 1;
  if (bh < 4 ||
      bw / bh > 1.4 ||
      bh / bw > 16 ||
      minX == 0 ||
      maxX == width - 1 ||
      minY == 0 ||
      maxY == height - 1) {
    return {
      'score': null,
      'reason': 'Traço cortado, borda da tabela ou formato duvidoso.',
    };
  }
  final glyph = img.Image(width: bw, height: bh, numChannels: 1);
  for (final i in pixels) {
    glyph.setPixelRgba(i % width - minX, i ~/ width - minY, 255, 255, 255, 255);
  }
  final scale = 20 / math.max(bw, bh);
  final small = img.copyResize(
    glyph,
    width: math.max(1, (bw * scale).round()),
    height: math.max(1, (bh * scale).round()),
    interpolation: img.Interpolation.average,
  );
  final input = List<double>.filled(784, 0);
  final ox = (28 - small.width) ~/ 2, oy = (28 - small.height) ~/ 2;
  for (var y = 0; y < small.height; y++) {
    for (var x = 0; x < small.width; x++) {
      input[(y + oy) * 28 + x + ox] = small.getPixel(x, y).r / 255;
    }
  }
  final prediction = model.predict(input);
  return {
    'score': prediction.accepted,
    'confidence': prediction.probability,
    'reason': prediction.accepted == null
        ? 'Dígito fora de 0–5 ou baixa confiança.'
        : null,
  };
}
