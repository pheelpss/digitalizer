import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digitalizer/main.dart';

void main() {
  testWidgets(
    'Digitalizer abre como aplicativo independente com ação de captura',
    (tester) async {
      await tester.pumpWidget(const Digitalizer());
      expect(find.text('Digitalizer'), findsOneWidget);
      expect(find.text('Do papel para as notas'), findsOneWidget);
      expect(find.text('Fotografar relatório'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
