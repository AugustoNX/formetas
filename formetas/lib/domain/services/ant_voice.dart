import '../entities/insight.dart';

/// Frases da formiguinha para cada insight.
///
/// Cada tipo tem algumas variações; a escolhida depende do id do insight e
/// da semana corrente, então o texto muda de uma semana para outra mas fica
/// estável durante a semana (sem "piscar" a cada rebuild).
class AntVoice {
  const AntVoice();

  /// Formata em reais sem centavos: `R$ 1.234`. Negativos: `-R$ 50`.
  static String money(double value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}R\$ $buffer';
  }

  static String percent(double ratio) => '${(ratio * 100).round()}%';

  /// Número da semana desde 05/01/1970 (segunda-feira), em horário local.
  static int weekNumber(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
  }

  /// Hash FNV-1a de 32 bits, estável entre execuções e plataformas.
  static int stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Escolhe uma variação e substitui `{chaves}` por [vars].
  ({String title, String message}) speak({
    required String id,
    required String templateKey,
    required DateTime now,
    Map<String, String> vars = const {},
  }) {
    final variants = _templates[templateKey];
    if (variants == null || variants.isEmpty) {
      throw ArgumentError.value(templateKey, 'templateKey', 'sem frases');
    }
    final index = stableHash('$id#${weekNumber(now)}') % variants.length;
    final chosen = variants[index];
    return (title: _fill(chosen.$1, vars), message: _fill(chosen.$2, vars));
  }

  /// Linha curta para o recado semanal do formigueiro.
  String weeklyHeadline(Insight insight) => insight.title;

  static String _fill(String template, Map<String, String> vars) =>
      template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);

  static const Map<String, List<(String, String)>> _templates = {
    'forecast.red': [
      ('O mês pode fechar no vermelho',
          'No ritmo atual, faltam {deficit} até o fim de {month}. Dá tempo de ajustar.'),
      ('Atenção ao fim de {month}',
          'A previsão é gastar {deficit} a mais do que entra. Vamos segurar o passo?'),
      ('Formiga sente chuva chegando',
          'Se nada mudar, {month} termina {deficit} no negativo.'),
    ],
    'forecast.tight': [
      ('Mês justo',
          'A previsão é sobrar só {margin} em {month}. Qualquer imprevisto aperta.'),
      ('Folga pequena em {month}',
          'No ritmo atual, sobram {margin} até o fim de {month}.'),
    ],
    'forecast.ok': [
      ('Mês no caminho certo',
          'No ritmo atual, devem sobrar {margin} até o fim de {month}.'),
      ('Formigueiro abastecido',
          'Se o passo continuar, {month} fecha com {margin} de sobra.'),
    ],
    'spike': [
      ('{cat} acima do normal',
          'Já foram {value} em {month}, {pct} acima da sua média de {avg}.'),
      ('{cat} disparou',
          'Em {month} já soma {value} — sua média é {avg}.'),
      ('Olho em {cat}',
          '{value} em {month} até agora, {diff} a mais que o habitual.'),
    ],
    'drop': [
      ('{cat} caiu bem',
          'Em {month}, {cat} ficou em {value}, {pct} abaixo da média. Boa, formiguinha!'),
      ('Economia em {cat}',
          'Você gastou {diff} a menos que o normal em {cat} em {month}.'),
    ],
    'trend': [
      ('{cat} sobe há 3 meses',
          'Passou de {first} em {firstMonth} para {last} em {month}. Vale entender o que mudou.'),
      ('{cat} em alta constante',
          'Três meses seguidos de aumento, chegando a {last} em {month}.'),
    ],
    'unusual': [
      ('Gasto fora do padrão',
          '{desc} ({value}) é bem maior que seus gastos típicos em {cat}.'),
      ('Esse foi grande',
          '{value} em {desc} — cerca de {times}x o seu normal em {cat}.'),
    ],
    'small': [
      ('Formiga ao contrário',
          '{n} comprinhas em {month} somam {value}. Pequenas, mas pesam.'),
      ('Migalhas que somam',
          'Compras de até {limit} já levaram {value} em {month} ({n} vezes).'),
      ('Os grãozinhos estão saindo',
          '{value} em {n} compras pequenas em {month}. A formiga junta, não espalha!'),
    ],
    'subscriptions': [
      ('Suas assinaturas: {value}/mês',
          '{n} cobranças recorrentes somam {yearly} por ano. Todas ainda valem a pena?'),
      ('{n} assinaturas ativas',
          'São {value} todo mês. Revise as que você quase não usa.'),
    ],
    'savings.great': [
      ('Você guardou {pct} da renda',
          'Em {month} sobraram {value}. Ritmo de formiga campeã!'),
      ('Ótima taxa de poupança',
          '{pct} da renda ficou com você em {month} ({value}).'),
    ],
    'savings.ok': [
      ('Poupança de {pct} em {month}',
          'Sobraram {value}. Chegar a 20% deixaria o formigueiro mais forte.'),
    ],
    'savings.low': [
      ('Sobrou pouco em {month}',
          'Só {pct} da renda ficou guardada ({value}).'),
      ('Poupança baixa',
          'Você guardou {pct} da renda em {month}. Uma trilha pode ajudar.'),
    ],
    'savings.negative': [
      ('{month} fechou no negativo',
          'Saíram {value} a mais do que entrou.'),
      ('Gastos acima da renda',
          'Em {month} as despesas passaram a renda em {value}.'),
    ],
    'income.soon': [
      ('{label} deve cair {when}',
          'Previsão de {value}, pelo seu histórico.'),
      ('Reforço chegando: {label}',
          'Esperado {when}, cerca de {value}.'),
    ],
    'income.late': [
      ('{label} ainda não apareceu',
          'Costuma cair por volta de {date} ({value}). Confira se já entrou.'),
    ],
    'goal.behind': [
      ('Meta "{goal}" precisa de fôlego',
          'Faltam {remaining}: são {needed}/mês até {date}, e você guarda em média {avg}.'),
      ('"{goal}" está apertada',
          'Para chegar em {date}, guarde {needed} por mês (hoje: {avg}).'),
    ],
  };
}
