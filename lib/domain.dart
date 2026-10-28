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
    r'^\s*([1-5])\s*[.,]\s*(\d{1,2})(?:\s|$|[.)])',
  ).firstMatch(text);
  return match == null ? null : '${match[1]}.${int.parse(match[2]!)}';
}
