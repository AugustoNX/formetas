import 'dart:math' as math;

import '../entities/goal_entity.dart';
import '../entities/insight.dart';
import '../entities/recurring_pattern.dart';
import '../entities/transaction_entity.dart';
import 'ant_voice.dart';

/// Dados de entrada do motor. Tudo já carregado em memória (on-device).
class InsightInput {
  const InsightInput({
    required this.transactions,
    required this.now,
    this.patterns = const [],
    this.goals = const [],
    this.reserveBalance = 0,
    this.dismissedIds = const {},
  });

  final List<TransactionEntity> transactions;
  final List<RecurringPattern> patterns;
  final List<GoalEntity> goals;

  /// Saldo somado das caixinhas/reservas.
  final double reserveBalance;
  final Set<String> dismissedIds;
  final DateTime now;
}

/// Limiares do motor. Valores padrão calibrados para evitar ruído.
class InsightThresholds {
  const InsightThresholds({
    this.spikeRatio = 1.3,
    this.spikeMinDiff = 80,
    this.minCategoryAverage = 50,
    this.dropRatio = 0.7,
    this.dropFloorRatio = 0.15,
    this.trendStep = 1.1,
    this.trendMinLast = 150,
    this.unusualFactor = 3,
    this.unusualMinValue = 200,
    this.unusualMinHistory = 4,
    this.smallPurchaseLimit = 30,
    this.smallMinCount = 8,
    this.smallMinTotal = 100,
    this.tightMargin = 0.1,
    this.incomeSoonDays = 5,
    this.incomeLateDays = 3,
    this.maxInsights = 8,
  });

  final double spikeRatio;
  final double spikeMinDiff;
  final double minCategoryAverage;
  final double dropRatio;

  /// Mínimo do mês passado em relação à média para uma "queda" contar
  /// como economia de verdade, e não como categoria que sumiu (R$ 0).
  final double dropFloorRatio;
  final double trendStep;
  final double trendMinLast;
  final double unusualFactor;
  final double unusualMinValue;
  final int unusualMinHistory;
  final double smallPurchaseLimit;
  final int smallMinCount;
  final double smallMinTotal;
  final double tightMargin;
  final int incomeSoonDays;
  final int incomeLateDays;
  final int maxInsights;
}

/// Motor de insights: regras determinísticas, puro Dart, sem rede.
class InsightEngine {
  const InsightEngine({
    this.thresholds = const InsightThresholds(),
    this.voice = const AntVoice(),
  });

  final InsightThresholds thresholds;
  final AntVoice voice;

  static const _monthNames = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  static const _monthFull = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  static String monthWord(DateTime date) => _monthFull[date.month - 1];

  static String monthTitle(DateTime date) {
    final word = monthWord(date);
    return '${word[0].toUpperCase()}${word.substring(1)} ${date.year}';
  }

  List<Insight> generate(InsightInput input) {
    final ctx = _Context(input, thresholds.smallPurchaseLimit);
    final all = <Insight?>[
      _forecast(ctx),
      ..._categoryChanges(ctx),
      ..._unusual(ctx),
      _smallPurchases(ctx),
      _subscriptions(ctx),
      _savingsRate(ctx),
      ..._incomeArrival(ctx),
      _goalPace(ctx),
    ].nonNulls.toList();
    return _rank(all, input.dismissedIds);
  }

  // ---------------------------------------------------------------- ranking

  List<Insight> _rank(List<Insight> all, Set<String> dismissed) {
    final visible = all.where((i) => !dismissed.contains(i.id)).toList()
      ..sort((a, b) {
        final bySeverity = b.severity.index.compareTo(a.severity.index);
        if (a.severity == InsightSeverity.alert || b.severity == InsightSeverity.alert) {
          if (bySeverity != 0) return bySeverity;
        }
        return b.score.compareTo(a.score);
      });

    // Uma leitura por categoria: a mais forte vence (pico > tendência).
    final seenCategories = <String>{};
    final result = <Insight>[];
    for (final insight in visible) {
      final cat = insight.category;
      final perCategory = insight.type == InsightType.categorySpike ||
          insight.type == InsightType.categoryTrend ||
          insight.type == InsightType.categoryDrop;
      if (perCategory && cat != null && !seenCategories.add(_Context.keyOf(cat))) continue;
      result.add(insight);
      if (result.length >= thresholds.maxInsights) break;
    }
    return result;
  }

  // --------------------------------------------------------------- forecast

  Insight? _forecast(_Context c) {
    if (c.incomeMonth(0) <= 0 && c.expenseMonth(0) <= 0 && c.pendingIncome <= 0) {
      return null;
    }
    final day = c.today.day;
    final remainingDays = c.daysInMonth - day;
    final variableToDate = c.variableToDate;
    final historicalVariable = c.historicalVariableAverage;
    final weight = day / c.daysInMonth;
    final currentPace = variableToDate / day;
    final historicalPace = historicalVariable > 0 ? historicalVariable / c.daysInMonth : currentPace;
    final dailyPace = weight * currentPace + (1 - weight) * historicalPace;
    final paceRemaining = dailyPace * remainingDays;

    final income = c.incomeMonth(0) + c.pendingIncome;
    final expense = c.expenseMonth(0) + paceRemaining + c.pendingBills;
    final balance = income - expense;
    final id = 'monthForecast-${c.monthKey}';

    final details = <String>[
      'Entradas: ${AntVoice.money(c.incomeMonth(0))} lançadas'
          '${c.pendingIncome > 0 ? ' + ${AntVoice.money(c.pendingIncome)} previstas' : ''}',
      'Saídas lançadas: ${AntVoice.money(c.expenseMonth(0))}',
      'Ritmo do dia a dia: ~${AntVoice.money(dailyPace)}/dia '
          '(${AntVoice.money(paceRemaining)} até o fim de ${c.monthWord(0)})',
      if (c.pendingBills > 0) 'Contas fixas ainda por vir: ${AntVoice.money(c.pendingBills)}',
    ];
    final series = [
      InsightPoint('Entradas', income),
      InsightPoint('Lançado', c.expenseMonth(0)),
      InsightPoint('Ritmo', paceRemaining),
      InsightPoint('Fixas', c.pendingBills),
    ];
    final metrics = {
      'income': income,
      'expense': expense,
      'balance': balance,
      'dailyPace': dailyPace,
      'pendingBills': c.pendingBills,
      'pendingIncome': c.pendingIncome,
    };

    if (balance < 0) {
      final deficit = -balance;
      final text = voice.speak(
        id: id, templateKey: 'forecast.red', now: c.now,
        vars: {'deficit': AntVoice.money(deficit), 'month': c.monthWord(0)},
      );
      final perDay = remainingDays > 0 ? deficit / remainingDays : deficit;
      return Insight(
        id: id,
        type: InsightType.monthForecast,
        severity: InsightSeverity.alert,
        score: 100 + math.min(deficit / 50, 50),
        title: text.title,
        message: text.message,
        amount: balance,
        metrics: metrics,
        series: series,
        details: [
          ...details,
          if (remainingDays > 0)
            'Para empatar: gaste ~${AntVoice.money(math.max(0, dailyPace - perDay))}/dia no variável.',
          if (c.input.reserveBalance >= deficit)
            'Sua reserva cobriria a diferença, mas o ideal é não precisar dela.',
        ],
        action: const InsightAction(type: InsightActionType.openTransactions, label: 'Ver lançamentos'),
        periodLabel: c.monthTitle(0, ongoing: true),
      );
    }

    if (day < 5) return null; // cedo demais para afirmar que está tudo bem
    final tight = income > 0 && balance < income * thresholds.tightMargin;
    final text = voice.speak(
      id: id, templateKey: tight ? 'forecast.tight' : 'forecast.ok', now: c.now,
      vars: {'margin': AntVoice.money(balance), 'month': c.monthWord(0)},
    );
    return Insight(
      id: id,
      type: InsightType.monthForecast,
      severity: tight ? InsightSeverity.warning : InsightSeverity.positive,
      score: tight ? 70 : 28,
      title: text.title,
      message: text.message,
      amount: balance,
      metrics: metrics,
      series: series,
      details: details,
      periodLabel: c.monthTitle(0, ongoing: true),
    );
  }

  // ------------------------------------------------------ category changes

  List<Insight> _categoryChanges(_Context c) {
    final out = <Insight>[];
    for (final key in c.categoryKeys) {
      if (key.isEmpty) continue;
      final label = c.categoryLabel[key]!;
      if (label.isEmpty) continue;
      final m = [for (var i = 0; i <= 4; i++) c.categoryMonth(key, i)];
      final curToDate = c.categoryToDate(key);
      final series = [
        for (var i = 3; i >= 1; i--) InsightPoint(c.monthLabel(i), m[i]),
        InsightPoint(c.monthLabel(0), curToDate, highlight: true),
      ];

      // Pico: mês corrente (só o que já aconteceu) vs média dos 3 anteriores.
      final prev = [m[1], m[2], m[3]].where((v) => v > 0).toList();
      if (prev.length >= 2) {
        final avg = prev.reduce((a, b) => a + b) / prev.length;
        final diff = curToDate - avg;
        if (avg >= thresholds.minCategoryAverage &&
            curToDate >= avg * thresholds.spikeRatio &&
            diff >= thresholds.spikeMinDiff) {
          final id = 'categorySpike-${c.monthKey}-$key';
          final text = voice.speak(id: id, templateKey: 'spike', now: c.now, vars: {
            'cat': label,
            'value': AntVoice.money(curToDate),
            'avg': AntVoice.money(avg),
            'diff': AntVoice.money(diff),
            'pct': AntVoice.percent(diff / avg),
            'month': c.monthWord(0),
          });
          final strong = curToDate >= avg * 2 && diff >= 300;
          out.add(Insight(
            id: id,
            type: InsightType.categorySpike,
            severity: strong ? InsightSeverity.alert : InsightSeverity.warning,
            score: 60 + math.min(diff / 20, 30),
            title: text.title,
            message: text.message,
            amount: curToDate,
            category: label,
            metrics: {'current': curToDate, 'average': avg, 'diff': diff},
            series: series,
            details: [
              'Média dos últimos meses: ${AntVoice.money(avg)}',
              '${c.monthTitle(0, ongoing: true)}: ${AntVoice.money(curToDate)}',
            ],
            action: InsightAction(
              type: InsightActionType.createTrail,
              label: 'Criar trilha',
              category: label,
            ),
            periodLabel: c.monthTitle(0, ongoing: true),
          ));
        }
      }

      // Queda: mês passado vs média dos 3 antes dele.
      // Exige gasto real no mês passado — R$ 0 quase sempre é categoria
      // parada, renomeada ou mês agrupado errado, não uma economia.
      final older = [m[2], m[3], m[4]].where((v) => v > 0).toList();
      final last = m[1];
      if (older.length >= 2) {
        final avg = older.reduce((a, b) => a + b) / older.length;
        final diff = avg - last;
        if (last.round() > 0 &&
            last >= avg * thresholds.dropFloorRatio &&
            avg >= thresholds.minCategoryAverage &&
            last <= avg * thresholds.dropRatio &&
            diff >= thresholds.spikeMinDiff) {
          final id = 'categoryDrop-${c.monthKey}-$key';
          final text = voice.speak(id: id, templateKey: 'drop', now: c.now, vars: {
            'cat': label,
            'value': AntVoice.money(last),
            'diff': AntVoice.money(diff),
            'pct': AntVoice.percent(diff / avg),
            'month': c.monthWord(1),
          });
          out.add(Insight(
            id: id,
            type: InsightType.categoryDrop,
            severity: InsightSeverity.positive,
            score: 30 + math.min(diff / 40, 15),
            title: text.title,
            message: text.message,
            amount: last,
            category: label,
            metrics: {'last': last, 'average': avg, 'diff': diff},
            series: [
              for (var i = 4; i >= 2; i--) InsightPoint(c.monthLabel(i), m[i]),
              InsightPoint(c.monthLabel(1), last, highlight: true),
            ],
            details: [
              '${c.monthTitle(1)}: ${AntVoice.money(last)} em $label',
              'Média anterior: ${AntVoice.money(avg)}',
            ],
            periodLabel: c.monthTitle(1),
          ));
        }
      }

      // Tendência: 3 meses fechados subindo.
      if (m[3] > 0 &&
          m[2] >= m[3] * thresholds.trendStep &&
          m[1] >= m[2] * thresholds.trendStep &&
          m[1] >= thresholds.trendMinLast) {
        final id = 'categoryTrend-${c.monthKey}-$key';
        final growth = m[1] / m[3] - 1;
        final text = voice.speak(id: id, templateKey: 'trend', now: c.now, vars: {
          'cat': label,
          'first': AntVoice.money(m[3]),
          'last': AntVoice.money(m[1]),
          'firstMonth': c.monthWord(3),
          'month': c.monthWord(1),
        });
        out.add(Insight(
          id: id,
          type: InsightType.categoryTrend,
          severity: InsightSeverity.warning,
          score: 50 + math.min(growth * 20, 20),
          title: text.title,
          message: text.message,
          amount: m[1],
          category: label,
          metrics: {'first': m[3], 'last': m[1], 'growth': growth},
          series: [
            for (var i = 3; i >= 1; i--)
              InsightPoint(c.monthLabel(i), m[i], highlight: i == 1),
          ],
          details: [
            'De ${c.monthTitle(3)} a ${c.monthTitle(1)}',
            'Crescimento de ${AntVoice.percent(growth)} em 3 meses',
          ],
          action: InsightAction(
            type: InsightActionType.createTrail,
            label: 'Criar trilha',
            category: label,
          ),
          periodLabel: c.monthTitle(1),
        ));
      }
    }
    return out;
  }

  // -------------------------------------------------------------- unusual

  List<Insight> _unusual(_Context c) {
    final candidates = <(TransactionEntity, double, double)>[];
    for (final tx in c.currentExpensesToDate) {
      if (c.recurringIds.contains(tx.id)) continue;
      if (tx.value < thresholds.unusualMinValue) continue;
      final history = c.categoryHistoryValues(_Context.keyOf(tx.category));
      if (history.length < thresholds.unusualMinHistory) continue;
      final median = _median(history);
      if (median <= 0 || tx.value < median * thresholds.unusualFactor) continue;
      candidates.add((tx, median, tx.value / median));
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    return [
      for (final (tx, median, times) in candidates.take(2))
        () {
          final id = 'unusualExpense-${tx.id}';
          final desc = tx.description.trim().isEmpty ? tx.category : tx.description.trim();
          final text = voice.speak(id: id, templateKey: 'unusual', now: c.now, vars: {
            'desc': desc,
            'value': AntVoice.money(tx.value),
            'cat': tx.category,
            'times': times.toStringAsFixed(0),
          });
          return Insight(
            id: id,
            type: InsightType.unusualExpense,
            severity: InsightSeverity.info,
            score: 40 + math.min(times * 3, 20),
            title: text.title,
            message: text.message,
            amount: tx.value,
            category: tx.category,
            metrics: {'value': tx.value, 'median': median, 'times': times},
            series: [
              InsightPoint('Típico', median),
              InsightPoint('Este', tx.value, highlight: true),
            ],
            details: [
              'Gasto típico em ${tx.category}: ${AntVoice.money(median)}',
              'Data: ${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}',
            ],
            action: const InsightAction(type: InsightActionType.openTransactions, label: 'Ver lançamento'),
            periodLabel: c.monthTitle(0, ongoing: true),
          );
        }(),
    ];
  }

  // ------------------------------------------------------ small purchases

  Insight? _smallPurchases(_Context c) {
    final small = c.currentExpensesToDate
        .where((t) => t.value <= thresholds.smallPurchaseLimit && !c.recurringIds.contains(t.id))
        .toList();
    final total = small.fold(0.0, (a, t) => a + t.value);
    if (small.length < thresholds.smallMinCount || total < thresholds.smallMinTotal) return null;

    final id = 'smallPurchases-${c.monthKey}';
    final text = voice.speak(id: id, templateKey: 'small', now: c.now, vars: {
      'n': '${small.length}',
      'value': AntVoice.money(total),
      'limit': AntVoice.money(thresholds.smallPurchaseLimit),
      'month': c.monthWord(0),
    });
    final weekly = List<double>.filled(5, 0);
    for (final t in small) {
      weekly[math.min((t.date.day - 1) ~/ 7, 4)] += t.value;
    }
    final byCategory = <String, double>{};
    for (final t in small) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.value;
    }
    final top = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final projected = total / c.today.day * c.daysInMonth;
    return Insight(
      id: id,
      type: InsightType.smallPurchases,
      severity: total >= 200 ? InsightSeverity.warning : InsightSeverity.info,
      score: 45 + math.min(total / 20, 20),
      title: text.title,
      message: text.message,
      amount: total,
      metrics: {'count': small.length.toDouble(), 'total': total, 'projected': projected},
      series: [
        for (var i = 0; i < 5; i++)
          if (i * 7 < c.today.day) InsightPoint('S${i + 1}', weekly[i]),
      ],
      details: [
        'No ritmo atual: ~${AntVoice.money(projected)} em ${c.monthWord(0)}',
        for (final e in top.take(3)) '${e.key}: ${AntVoice.money(e.value)}',
      ],
      action: const InsightAction(type: InsightActionType.createTrail, label: 'Criar trilha'),
      periodLabel: c.monthTitle(0, ongoing: true),
    );
  }

  // -------------------------------------------------------- subscriptions

  Insight? _subscriptions(_Context c) {
    final subs = c.input.patterns.where((p) => p.kind == RecurringKind.subscription).toList()
      ..sort((a, b) => _monthlyEquivalent(b).compareTo(_monthlyEquivalent(a)));
    if (subs.isEmpty) return null;
    final monthly = subs.fold(0.0, (a, p) => a + _monthlyEquivalent(p));
    if (subs.length < 2 && monthly < 40) return null;

    final id = 'subscriptions-${c.monthKey}';
    final text = voice.speak(id: id, templateKey: 'subscriptions', now: c.now, vars: {
      'n': '${subs.length}',
      'value': AntVoice.money(monthly),
      'yearly': AntVoice.money(monthly * 12),
    });
    return Insight(
      id: id,
      type: InsightType.subscriptions,
      severity: InsightSeverity.info,
      score: 35 + math.min(monthly / 20, 10),
      title: text.title,
      message: text.message,
      amount: monthly,
      metrics: {'monthly': monthly, 'count': subs.length.toDouble()},
      series: [for (final p in subs.take(6)) InsightPoint(_short(p.label), _monthlyEquivalent(p))],
      details: [
        for (final p in subs)
          '${p.label}: ${AntVoice.money(p.averageAmount)}'
              '${p.cadence == RecurrenceCadence.monthly ? '/mês' : p.cadence == RecurrenceCadence.yearly ? '/ano' : '/semana'}',
      ],
    );
  }

  // --------------------------------------------------------- savings rate

  Insight? _savingsRate(_Context c) {
    final income = c.incomeMonth(1);
    final lastExpense = c.expenseMonth(1);
    if (income <= 0 || lastExpense <= 0) return null;
    final saved = income - c.expenseMonth(1);
    final rate = saved / income;
    final id = 'savingsRate-${c.monthKey}';
    final (String key, InsightSeverity severity, double score) = switch (rate) {
      < 0 => ('savings.negative', InsightSeverity.alert, 75),
      < 0.05 => ('savings.low', InsightSeverity.warning, 55),
      < 0.2 => ('savings.ok', InsightSeverity.info, 20),
      _ => ('savings.great', InsightSeverity.positive, 32),
    };
    final text = voice.speak(id: id, templateKey: key, now: c.now, vars: {
      'pct': AntVoice.percent(rate),
      'value': AntVoice.money(saved.abs()),
      'month': c.monthWord(1),
    });
    return Insight(
      id: id,
      type: InsightType.savingsRate,
      severity: severity,
      score: score,
      title: text.title,
      message: text.message,
      amount: saved,
      metrics: {'rate': rate, 'saved': saved, 'income': income},
      series: [
        for (var i = 4; i >= 1; i--)
          InsightPoint(c.monthLabel(i), c.incomeMonth(i) - c.expenseMonth(i), highlight: i == 1),
      ],
      details: [
        '${c.monthTitle(1)} — renda ${AntVoice.money(income)} · despesas ${AntVoice.money(lastExpense)}',
        'Referência saudável: guardar 20% ou mais.',
      ],
      periodLabel: c.monthTitle(1),
    );
  }

  // -------------------------------------------------------- income arrival

  List<Insight> _incomeArrival(_Context c) {
    final out = <Insight>[];
    final today = c.today;
    for (final p in c.input.patterns) {
      if (p.type != TransactionType.income) continue;
      final expected = DateTime(p.expectedNextDate.year, p.expectedNextDate.month, p.expectedNextDate.day);
      final delta = expected.difference(today).inDays;
      final id = 'incomeArrival-${p.key}-${expected.year}-${expected.month}-${expected.day}';
      final date = '${expected.day.toString().padLeft(2, '0')}/${expected.month.toString().padLeft(2, '0')}';
      if (delta >= 0 && delta <= thresholds.incomeSoonDays) {
        final when = switch (delta) { 0 => 'hoje', 1 => 'amanhã', _ => 'em $delta dias' };
        final text = voice.speak(id: id, templateKey: 'income.soon', now: c.now, vars: {
          'label': p.label, 'when': when, 'value': AntVoice.money(p.averageAmount),
        });
        out.add(Insight(
          id: id,
          type: InsightType.incomeArrival,
          severity: InsightSeverity.positive,
          score: 22 + (p.kind == RecurringKind.salary ? 5 : 0),
          title: text.title,
          message: text.message,
          amount: p.averageAmount,
          metrics: {'daysUntil': delta.toDouble(), 'confidence': p.confidence},
          details: ['Data esperada: $date', 'Recebido ${p.occurrences} vezes'],
        ));
      } else if (-delta >= thresholds.incomeLateDays && -delta <= 10) {
        final text = voice.speak(id: id, templateKey: 'income.late', now: c.now, vars: {
          'label': p.label, 'date': date, 'value': AntVoice.money(p.averageAmount),
        });
        out.add(Insight(
          id: id,
          type: InsightType.incomeArrival,
          severity: InsightSeverity.warning,
          score: 50,
          title: text.title,
          message: text.message,
          amount: p.averageAmount,
          metrics: {'daysLate': (-delta).toDouble()},
          details: ['Esperado em $date'],
        ));
      }
    }
    return out;
  }

  // ------------------------------------------------------------ goal pace

  Insight? _goalPace(_Context c) {
    final savings = [for (var i = 1; i <= 3; i++) c.incomeMonth(i) - c.expenseMonth(i)];
    final avgSavings = math.max(0.0, savings.reduce((a, b) => a + b) / savings.length);
    Insight? worst;
    var worstGap = 0.0;
    for (final g in c.input.goals) {
      if (g.isCompleted || !g.targetDate.isAfter(c.now)) continue;
      final remaining = g.targetValue - g.currentValue;
      final goalDay = _Context.civilDay(g.targetDate);
      final monthsLeft = math.max(
        1,
        (goalDay.year - c.today.year) * 12 + goalDay.month - c.today.month,
      );
      final needed = remaining / monthsLeft;
      final gap = needed - avgSavings;
      if (needed < 50 || needed <= avgSavings * 1.1 || gap <= worstGap) continue;
      worstGap = gap;
      final id = 'goalPace-${c.monthKey}-${g.id}';
      final date = '${g.targetDate.month.toString().padLeft(2, '0')}/${g.targetDate.year}';
      final text = voice.speak(id: id, templateKey: 'goal.behind', now: c.now, vars: {
        'goal': g.name,
        'remaining': AntVoice.money(remaining),
        'needed': AntVoice.money(needed),
        'avg': AntVoice.money(avgSavings),
        'date': date,
      });
      worst = Insight(
        id: id,
        type: InsightType.goalPace,
        severity: InsightSeverity.warning,
        score: 40 + math.min(gap / 50, 15),
        title: text.title,
        message: text.message,
        amount: needed,
        metrics: {'needed': needed, 'avgSavings': avgSavings, 'remaining': remaining},
        series: [InsightPoint('Guarda', avgSavings), InsightPoint('Precisa', needed, highlight: true)],
        details: ['Progresso: ${g.progressPercent.toStringAsFixed(0)}%'],
        action: const InsightAction(type: InsightActionType.openGoals, label: 'Ver metas'),
      );
    }
    return worst;
  }

  // -------------------------------------------------------------- helpers

  static double _monthlyEquivalent(RecurringPattern p) => switch (p.cadence) {
        RecurrenceCadence.weekly => p.averageAmount * 52 / 12,
        RecurrenceCadence.monthly => p.averageAmount,
        RecurrenceCadence.yearly => p.averageAmount / 12,
      };

  static String _short(String label) => label.length <= 10 ? label : '${label.substring(0, 9)}…';

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

/// Agregações pré-calculadas uma única vez por execução.
class _Context {
  _Context(this.input, double smallLimit)
      : now = input.now,
        today = _Context.civilDay(input.now) {
    for (final p in input.patterns) {
      recurringIds.addAll(p.transactionIds);
    }
    for (final tx in input.transactions) {
      final offset = monthOffset(tx.date);
      if (offset < 0 || offset > 6) continue;
      if (tx.type == TransactionType.income) {
        _income[offset] = (_income[offset] ?? 0) + tx.value;
      } else if (tx.type == TransactionType.expense) {
        _expense[offset] = (_expense[offset] ?? 0) + tx.value;
        final key = keyOf(tx.category);
        categoryLabel.putIfAbsent(key, () => tx.category.trim());
        final byCat = _categoryByMonth.putIfAbsent(key, () => {});
        byCat[offset] = (byCat[offset] ?? 0) + tx.value;
        final variable = !recurringIds.contains(tx.id) && !tx.isInstallment;
        if (offset == 0) {
          if (!civilDay(tx.date).isAfter(today)) {
            currentExpensesToDate.add(tx);
            _categoryToDate[key] = (_categoryToDate[key] ?? 0) + tx.value;
            if (variable) variableToDate += tx.value;
          }
        } else {
          _history.putIfAbsent(key, () => []).add(tx.value);
          if (variable && offset <= 3) {
            _variableByMonth[offset] = (_variableByMonth[offset] ?? 0) + tx.value;
          }
        }
      }
    }
    final monthsWithVariable = _variableByMonth.values.where((v) => v > 0).length;
    historicalVariableAverage = monthsWithVariable == 0
        ? 0
        : _variableByMonth.values.fold(0.0, (a, b) => a + b) / monthsWithVariable;

    final idsThisMonth = {
      for (final tx in input.transactions)
        if (monthOffset(tx.date) == 0) tx.id,
    };
    for (final p in input.patterns) {
      final expectedDay = civilDay(p.expectedNextDate);
      if (monthOffset(p.expectedNextDate) != 0) continue;
      if (p.transactionIds.any(idsThisMonth.contains)) continue;
      if (p.type == TransactionType.income) {
        pendingIncome += p.averageAmount;
      } else if (p.type == TransactionType.expense && !expectedDay.isBefore(today)) {
        pendingBills += p.averageAmount;
      }
    }
  }

  final InsightInput input;
  final DateTime now;
  final DateTime today;
  final Set<String> recurringIds = {};
  final Map<int, double> _income = {};
  final Map<int, double> _expense = {};
  final Map<String, Map<int, double>> _categoryByMonth = {};
  final Map<String, double> _categoryToDate = {};
  final Map<String, List<double>> _history = {};
  final Map<int, double> _variableByMonth = {};
  final Map<String, String> categoryLabel = {};
  final List<TransactionEntity> currentExpensesToDate = [];
  double variableToDate = 0;
  double historicalVariableAverage = 0;
  double pendingIncome = 0;
  double pendingBills = 0;

  static String keyOf(String category) => category.trim().toLowerCase();

  /// Dia civil no fuso local — o mesmo critério do dashboard e da lista.
  static DateTime civilDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  int monthOffset(DateTime date) {
    final d = civilDay(date);
    return (today.year - d.year) * 12 + today.month - d.month;
  }

  Iterable<String> get categoryKeys => _categoryByMonth.keys;
  int get daysInMonth => DateTime(today.year, today.month + 1, 0).day;
  String get monthKey => '${today.year}-${today.month.toString().padLeft(2, '0')}';

  double incomeMonth(int offset) => _income[offset] ?? 0;
  double expenseMonth(int offset) => _expense[offset] ?? 0;
  double categoryMonth(String key, int offset) => _categoryByMonth[key]?[offset] ?? 0;
  double categoryToDate(String key) => _categoryToDate[key] ?? 0;
  List<double> categoryHistoryValues(String key) => _history[key] ?? const [];

  String monthLabel(int offset) {
    final d = monthOf(offset);
    return InsightEngine._monthNames[d.month - 1];
  }

  DateTime monthOf(int offset) => DateTime(today.year, today.month - offset);

  String monthWord(int offset) => InsightEngine.monthWord(monthOf(offset));

  String monthTitle(int offset, {bool ongoing = false}) {
    final title = InsightEngine.monthTitle(monthOf(offset));
    return ongoing ? '$title · até hoje' : title;
  }
}
