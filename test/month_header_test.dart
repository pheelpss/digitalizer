import 'package:flutter_test/flutter_test.dart';
import 'package:digitalizer/month_header.dart';

void main() {
  test('localiza palavras atuais mesmo junto ao cabeçalho anterior', () {
    final x = currentMonthCenter(const [
      HeaderWord('PADRONIZAÇÃO', 50, 100, 500, 120),
      HeaderWord('MÊS', 1100, 100, 1140, 120),
      HeaderWord('ANT.', 1145, 100, 1190, 120),
      HeaderWord('MÊS', 1400, 100, 1440, 120),
      HeaderWord('ATUAL', 1445, 100, 1510, 120),
    ]);
    expect(x, 1455);
  });
  test('não confunde anterior, texto agregado ou ATUAL isolado', () {
    expect(currentMonthCenter(const [HeaderWord('MÊS ANT.', 100, 10, 200, 30)]), isNull);
    expect(currentMonthCenter(const [HeaderWord('MÊS ANT. MÊS ATUAL', 100, 10, 400, 30)]), isNull);
    expect(currentMonthCenter(const [HeaderWord('ATUAL', 100, 10, 200, 30)]), isNull);
  });
  test('aceita etiqueta num elemento e rejeita palavras distantes', () {
    expect(currentMonthCenter(const [HeaderWord('MÊSATUAL', 1400, 10, 1500, 30)]), 1450);
    expect(currentMonthCenter(const [
      HeaderWord('MÊS', 100, 10, 130, 30),
      HeaderWord('ATUAL', 1400, 10, 1500, 30),
    ]), isNull);
  });
}
