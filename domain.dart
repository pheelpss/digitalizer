import 'dart:convert';

class Question {
  const Question(this.code, this.number, this.text);
  final String code, number, text;
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    json['categoryCode'] as String,
    json['number'] as String,
    json['question'] as String,
  );
}

class Catalog {
  Catalog(this.areas);
  final Map<String, List<Question>> areas;
  factory Catalog.parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return Catalog(
      raw.map(
        (key, value) => MapEntry(
          key,
          ((value as Map<String, dynamic>)['items'] as List<dynamic>)
              .map((q) => Question.fromJson(q as Map<String, dynamic>))
              .toList(),
        ),
      ),
    );
  }
  List<String> get names => areas.keys.toList()..sort();
  List<String> detectAreas(String header) {
    final padded = ' ${normalize(header)} ';
    return names
        .where(
          (area) => RegExp(
            r'(^|[^a-z0-9])' +
                RegExp.escape(normalize(area)) +
                r'($|[^a-z0-9])',
          ).hasMatch(padded),
        )
        .toList();
  }

  bool matches(String area, Iterable<String> codes) {
    final expected = areas[area]?.map((q) => q.number).toSet();
    final actual = codes.toList();
    return expected != null &&
        actual.length == expected.length &&
        actual.toSet().length == actual.length &&
        expected.containsAll(actual);
  }

  String? resolveNumber(String area, String text) {
    final questions = areas[area];
    if (questions == null) return questionNumber(text);
    final strict = questionNumber(text);
    if (questions.any((q) => q.number == strict)) return strict;
    final prefix = RegExp(r'^\s*([1-5])\s*([.,]?)\s*(\d{1,2})(?=\s|$|[A-Za-zÀ-ÖØ-öø-ÿ])')
        .firstMatch(text);
    if (prefix == null) return strict;
    final suffix = prefix[3]!;
    final candidates = <String>{};
    if (prefix[2]!.isEmpty && suffix.length == 1) {
      candidates.add('${prefix[1]}.$suffix');
    } else if (prefix[2]!.isNotEmpty && suffix.length == 2 && suffix.endsWith('0')) {
      candidates.add('${prefix[1]}.${suffix[0]}');
    }
    if (candidates.isEmpty) return strict;
    String clean(String value) => normalize(value)
        .replaceAll('0', 'o').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final body = clean(text.substring(prefix.end));
    if (body.length < 20) return strict;
    final ranked = questions.map((q) {
      final expected = clean(q.text);
      final length = body.length > expected.length ? body.length : expected.length;
      return MapEntry(q.number, _editDistance(body, expected) / length);
    }).toList()..sort((a, b) => a.value.compareTo(b.value));
    if (ranked.first.value <= .12 &&
        candidates.contains(ranked.first.key) &&
        (ranked.length == 1 || ranked[1].value - ranked.first.value >= .10)) {
      return ranked.first.key;
    }
    return strict;
  }

  String comparison(String area, Iterable<String> codes) {
    final expected = areas[area]?.map((q) => q.number).toList() ?? <String>[];
    final actual = codes.toList();
    final counts = <String, int>{};
    for (final code in actual) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
    String listing(Iterable<String> values) =>
        values.isEmpty ? 'nenhum' : values.join(', ');
    return 'Área: $area\n'
        'Esperadas: ${expected.length}; leituras: ${actual.length}; '
        'números distintos: ${counts.length}.\n'
        'Ausentes: ${listing(expected.where((n) => !counts.containsKey(n)))}\n'
        'Duplicados: ${listing(counts.entries.where((e) => e.value > 1).map((e) => '${e.key} (${e.value} vezes)'))}\n'
        'Inesperados: ${listing(counts.keys.where((n) => !expected.contains(n)))}\n'
        'Números reconhecidos: ${listing(actual)}';
  }
}

String normalize(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  var value = text.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    value = value.replaceAll(from[i], to[i]);
  }
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? questionNumber(String text) {
  final match = RegExp(
    r'^\s*([1-5])\s*[.,]\s*(\d{1,2})(?=\s|$|[.)]|[A-Za-zÀ-ÖØ-öø-ÿ])',
  ).firstMatch(text);
  return match == null ? null : '${match[1]}.${int.parse(match[2]!)}';
}

int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      final best = deletion < insertion ? deletion : insertion;
      current[j] = best < substitution ? best : substitution;
    }
    previous = current;
  }
  return previous.last;
}
