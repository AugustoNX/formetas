import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/services/ant_voice.dart';

void main() {
  const voice = AntVoice();

  test('formata reais sem centavos', () {
    expect(AntVoice.money(1234.6), r'R$ 1.235');
    expect(AntVoice.money(-50), r'-R$ 50');
    expect(AntVoice.money(1000000), r'R$ 1.000.000');
    expect(AntVoice.percent(0.256), '26%');
  });

  test('mesma semana = mesma frase; preenche variáveis', () {
    final a = voice.speak(id: 'x', templateKey: 'spike', now: DateTime(2026, 6, 15),
        vars: {'cat': 'Mercado', 'value': r'R$ 900', 'avg': r'R$ 600', 'diff': r'R$ 300', 'pct': '50%', 'month': 'junho'});
    final b = voice.speak(id: 'x', templateKey: 'spike', now: DateTime(2026, 6, 20),
        vars: {'cat': 'Mercado', 'value': r'R$ 900', 'avg': r'R$ 600', 'diff': r'R$ 300', 'pct': '50%', 'month': 'junho'});
    expect(a, b);
    expect(a.title + a.message, isNot(contains('{')));
    expect(a.title, contains('Mercado'));
  });

  test('queda cita a categoria e o valor, nunca um placeholder', () {
    final text = voice.speak(
      id: 'drop-1',
      templateKey: 'drop',
      now: DateTime(2026, 6, 15),
      vars: {
        'cat': 'Alimentação',
        'value': r'R$ 250',
        'diff': r'R$ 550',
        'pct': '69%',
        'month': 'maio',
      },
    );
    expect(text.title + text.message, isNot(contains('{')));
    expect(text.title + text.message, contains('Alimentação'));
    expect(text.message, isNot(contains('R\$ 0')));
  });

  test('frase varia entre semanas', () {
    final titles = {
      for (var w = 0; w < 12; w++)
        voice.speak(id: 'y', templateKey: 'small', now: DateTime(2026, 1, 5 + 7 * w),
            vars: const {'n': '9', 'value': r'R$ 150', 'limit': r'R$ 30', 'month': 'junho'}).title,
    };
    expect(titles.length, greaterThan(1));
  });

  test('semana começa na segunda', () {
    expect(AntVoice.weekNumber(DateTime(2026, 11, 2)), AntVoice.weekNumber(DateTime(2026, 11, 8)));
    expect(AntVoice.weekNumber(DateTime(2026, 11, 9)), AntVoice.weekNumber(DateTime(2026, 11, 8)) + 1);
  });

  test('chave inexistente falha explicitamente', () {
    expect(() => voice.speak(id: 'z', templateKey: 'nope', now: DateTime(2026)), throwsArgumentError);
  });
}
