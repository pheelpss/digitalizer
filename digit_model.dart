import 'dart:math' as math;
import 'dart:typed_data';

class DigitPrediction {
  const DigitPrediction(this.digit, this.probability, this.margin);
  final int digit;
  final double probability, margin;
  // Não renormalizar 0..5: reconhecer 6..9 deve rejeitar a entrada.
  int? get accepted =>
      digit <= 5 && probability >= .97 && margin >= .70 ? digit : null;
}

class DigitModel {
  DigitModel(Uint8List bytes) {
    if (bytes.length < 16) {
      throw const FormatException('Modelo de dígitos incompleto.');
    }
    final view = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes.take(4)) != 'DGZ1') {
      throw const FormatException('Modelo de dígitos inválido.');
    }
    inputs = view.getUint32(4, Endian.little);
    hidden = view.getUint32(8, Endian.little);
    outputs = view.getUint32(12, Endian.little);
    final count = inputs * hidden + hidden + hidden * outputs + outputs;
    if (inputs != 784 || outputs != 10 || bytes.length != 16 + count * 4) {
      throw const FormatException('Dimensões do modelo inválidas.');
    }
    weights = Float32List(count);
    for (var i = 0; i < count; i++) {
      weights[i] = view.getFloat32(16 + i * 4, Endian.little);
    }
  }
  late final int inputs, hidden, outputs;
  late final Float32List weights;

  DigitPrediction predict(List<double> pixels) {
    if (pixels.length != inputs) throw ArgumentError('Esperados 784 pixels.');
    final h = Float64List(hidden);
    final bias = inputs * hidden;
    for (var j = 0; j < hidden; j++) {
      var sum = weights[bias + j].toDouble();
      for (var i = 0; i < inputs; i++) {
        sum += pixels[i] * weights[i * hidden + j];
      }
      h[j] = math.max(0.0, sum);
    }
    final start = bias + hidden;
    final logits = List<double>.filled(outputs, 0);
    for (var j = 0; j < outputs; j++) {
      var sum = weights[start + hidden * outputs + j].toDouble();
      for (var i = 0; i < hidden; i++) {
        sum += h[i] * weights[start + i * outputs + j];
      }
      logits[j] = sum;
    }
    final maxLogit = logits.reduce(math.max);
    final exp = logits.map((n) => math.exp(n - maxLogit)).toList();
    final total = exp.reduce((a, b) => a + b);
    final order = List<int>.generate(outputs, (i) => i)
      ..sort((a, b) => exp[b].compareTo(exp[a]));
    return DigitPrediction(
      order[0],
      exp[order[0]] / total,
      (exp[order[0]] - exp[order[1]]) / total,
    );
  }
}
