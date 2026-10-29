import 'domain.dart';

class HeaderWord {
  const HeaderWord(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;
  String get label => normalize(text).replaceAll(RegExp(r'[^a-z]'), '');
}

// Recebe apenas elementos de uma mesma linha OCR. Nunca usa a caixa da linha.
double? currentMonthCenter(List<HeaderWord> words) {
  final ordered = List<HeaderWord>.of(words)
    ..sort((a, b) => a.left.compareTo(b.left));
  for (var i = 0; i < ordered.length; i++) {
    final word = ordered[i];
    if (word.label == 'mesatual') return (word.left + word.right) / 2;
    if (word.label != 'atual' || i == 0) continue;
    final month = ordered[i - 1];
    if (month.label != 'mes') continue;
    final h1 = month.bottom - month.top;
    final h2 = word.bottom - word.top;
    final height = h1 > h2 ? h1 : h2;
    final overlap = (month.bottom < word.bottom ? month.bottom : word.bottom) -
        (month.top > word.top ? month.top : word.top);
    if (height <= 0 || overlap <= 0 || word.left - month.right > height * 3) {
      continue;
    }
    return (month.left + word.right) / 2;
  }
  return null;
}
