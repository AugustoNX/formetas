import '../../core/constants/anthill_catalog.dart';
import '../entities/ant_profile_entity.dart';
import '../entities/anthill_snapshot.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';

/// Missão da semana, trilha de 7 dias, passos até o inverno e o recado.
///
/// Tudo é lido das transações e transferências. O perfil só guarda a categoria
/// escolhida na trilha e o que já foi comemorado.
class AnthillRhythm {
  const AnthillRhythm();

  WeeklyChallenge challenge({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required DateTime now,
  }) {
    final today = _date(now);
    final monday = _monday(today);
    final lastMonday = monday.subtract(const Duration(days: 7));
    final lastSunday = monday.subtract(const Duration(days: 1));

    final lastWeek = _byCategory(transactions, lastMonday, lastSunday);
    final top = _top(lastWeek);
    if (top != null && top.amount >= 40) {
      return _spendLess(
        transactions: transactions,
        now: now,
        monday: monday,
        category: top.name,
        lastAmount: top.amount,
      );
    }

    final recent = _top(
      _byCategory(
        transactions,
        monday.subtract(const Duration(days: 21)),
        lastSunday,
      ),
    );
    if (recent != null && recent.amount > 0) {
      return _pause(
        transactions: transactions,
        now: now,
        monday: monday,
        category: recent.name,
      );
    }

    return _store(
      transactions: transactions,
      transfers: transfers,
      now: now,
      monday: monday,
      lastMonday: lastMonday,
      lastSunday: lastSunday,
    );
  }

  String weeklyNote({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required DateTime now,
  }) {
    final today = _date(now);
    final monday = _monday(today);
    final spentBy = _byCategory(transactions, monday, today);
    final spent = spentBy.values.fold(0.0, (sum, value) => sum + value);
    final stored = _reserveNet(transfers, monday, today);
    final top = _top(spentBy);

    if (spent <= 0 && stored <= 0) {
      return 'A semana ainda está quieta. Sua formiga espera o primeiro passo.';
    }
    if (spent > 0 && stored > 0 && top != null) {
      return 'Você deixou ${_money(spent)} no caminho, a maior parte em '
          '${top.name}, e guardou ${_money(stored)} no armazém.';
    }
    if (spent > 0 && top != null) {
      return 'Você deixou ${_money(spent)} no caminho, a maior parte em ${top.name}.';
    }
    return 'Você guardou ${_money(stored)} no armazém. '
        'A formiga levou tudo para dentro.';
  }

  SpendingTrail trail({
    required List<TransactionEntity> transactions,
    required AntProfileEntity profile,
    required DateTime now,
  }) {
    final category = profile.trailCategory?.trim();
    final started = profile.trailStartedOn;
    if (category == null || category.isEmpty || started == null) {
      return SpendingTrail.inactive;
    }

    final start = _date(started);
    if (profile.trailCelebrated) {
      return SpendingTrail(
        category: category,
        startedOn: start,
        days: List.filled(SpendingTrail.length, true),
        finished: true,
      );
    }

    final today = _date(now);
    final days = List<bool?>.filled(SpendingTrail.length, null);
    final wanted = category.toLowerCase();
    for (var i = 0; i < SpendingTrail.length; i++) {
      final day = start.add(Duration(days: i));
      if (day.isAfter(today)) break;
      final spent = transactions.any(
        (transaction) =>
            transaction.type == TransactionType.expense &&
            _sameDay(transaction.date, day) &&
            transaction.category.trim().toLowerCase() == wanted,
      );
      days[i] = !spent;
    }

    final last = start.add(const Duration(days: SpendingTrail.length - 1));
    return SpendingTrail(
      category: category,
      startedOn: start,
      days: days,
      finished: today.isAfter(last),
    );
  }

  int seasonSteps({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required DateTime now,
  }) {
    final start = _seasonStart(now);
    var monday = _monday(start);
    if (monday.isBefore(start)) {
      monday = monday.add(const Duration(days: 7));
    }

    final current = _monday(now);
    var steps = 0;
    var guard = 0;
    while (!monday.isAfter(current) && guard < 60) {
      final sunday = monday.add(const Duration(days: 6));
      final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
      final asOf = end.isAfter(now) ? now : end;
      if (challenge(
        transactions: transactions,
        transfers: transfers,
        now: asOf,
      ).isComplete) {
        steps++;
      }
      monday = monday.add(const Duration(days: 7));
      guard++;
    }
    return steps;
  }

  WeeklyChallenge _spendLess({
    required List<TransactionEntity> transactions,
    required DateTime now,
    required DateTime monday,
    required String category,
    required double lastAmount,
  }) {
    final today = _date(now);
    final sunday = monday.add(const Duration(days: 6));
    final reduction = _reduction(lastAmount);
    final allowed = lastAmount - reduction;
    final spent = _byCategory(transactions, monday, today)[category] ?? 0;
    final ended = _weekEnded(now, sunday);
    final complete = ended && spent <= allowed + 0.009;

    final String detail;
    if (complete) {
      detail = _stepDone;
    } else if (spent > allowed + 0.009) {
      detail = 'A formiga parou. Passou ${_money(spent - allowed)} '
          'do combinado em $category.';
    } else {
      detail = 'Até domingo, pode gastar mais ${_money(allowed - spent)} '
          'em $category.';
    }

    return WeeklyChallenge(
      id: _id(monday, WeeklyChallengeKind.spendLess, category),
      kind: WeeklyChallengeKind.spendLess,
      title: 'Gaste ${_money(reduction)} a menos em $category '
          'do que na semana passada.',
      detail: detail,
      icon: AntIcon.leaf,
      unit: AnthillUnit.currency,
      current: spent,
      target: allowed,
      isComplete: complete,
      progressLabel: '${_money(spent)} de ${_money(allowed)}',
      category: category,
    );
  }

  WeeklyChallenge _pause({
    required List<TransactionEntity> transactions,
    required DateTime now,
    required DateTime monday,
    required String category,
  }) {
    const goal = 5;
    final streak = _cleanStreak(
      transactions: transactions,
      category: category,
      today: _date(now),
      goal: goal,
    );
    final complete = streak >= goal;
    final missing = goal - streak;

    final String detail;
    if (complete) {
      detail = _stepDone;
    } else if (streak == 0) {
      detail = 'A formiga parou. Hoje teve lançamento em $category.';
    } else {
      final days = missing == 1 ? 'dia' : 'dias';
      detail = 'Faltam $missing $days sem $category.';
    }

    return WeeklyChallenge(
      id: _id(monday, WeeklyChallengeKind.pause, category),
      kind: WeeklyChallengeKind.pause,
      title: 'Fique sem lançamento em $category por 5 dias.',
      detail: detail,
      icon: AntIcon.streak,
      unit: AnthillUnit.count,
      current: streak.toDouble(),
      target: goal.toDouble(),
      isComplete: complete,
      progressLabel: '$streak de $goal dias',
      category: category,
    );
  }

  WeeklyChallenge _store({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required DateTime now,
    required DateTime monday,
    required DateTime lastMonday,
    required DateTime lastSunday,
  }) {
    final today = _date(now);
    final thisIncome = _income(transactions, monday, today);
    final lastIncome = _income(transactions, lastMonday, lastSunday);
    final target = _storeTarget(thisIncome > 0 ? thisIncome : lastIncome);
    final stored = _reserveNet(transfers, monday, today);
    final complete = stored + 0.009 >= target;
    final detail = complete
        ? _stepDone
        : 'Faltam ${_money(target - stored)} para a caixinha até domingo.';

    return WeeklyChallenge(
      id: _id(monday, WeeklyChallengeKind.store, ''),
      kind: WeeklyChallengeKind.store,
      title: 'Leve ${_money(target)} para a caixinha até domingo.',
      detail: detail,
      icon: AntIcon.storage,
      unit: AnthillUnit.currency,
      current: stored,
      target: target,
      isComplete: complete,
      progressLabel: '${_money(stored)} de ${_money(target)}',
    );
  }

  int _cleanStreak({
    required List<TransactionEntity> transactions,
    required String category,
    required DateTime today,
    required int goal,
  }) {
    final wanted = category.trim().toLowerCase();
    var streak = 0;
    for (var i = 0; i < goal; i++) {
      final day = today.subtract(Duration(days: i));
      final spent = transactions.any(
        (transaction) =>
            transaction.type == TransactionType.expense &&
            _sameDay(transaction.date, day) &&
            transaction.category.trim().toLowerCase() == wanted,
      );
      if (spent) break;
      streak++;
    }
    return streak;
  }

  Map<String, double> _byCategory(
    List<TransactionEntity> transactions,
    DateTime start,
    DateTime end,
  ) {
    final totals = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      if (!_contains(transaction.date, start, end)) continue;
      final name = transaction.category.trim().isEmpty
          ? 'Outros'
          : transaction.category.trim();
      totals[name] = (totals[name] ?? 0) + transaction.value;
    }
    return totals;
  }

  _CategoryAmount? _top(Map<String, double> totals) {
    _CategoryAmount? best;
    final names = totals.keys.toList()..sort();
    for (final name in names) {
      final amount = totals[name] ?? 0;
      if (best == null || amount > best.amount) {
        best = _CategoryAmount(name, amount);
      }
    }
    return best;
  }

  double _income(
    List<TransactionEntity> transactions,
    DateTime start,
    DateTime end,
  ) {
    var total = 0.0;
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.income) continue;
      if (!_contains(transaction.date, start, end)) continue;
      total += transaction.value;
    }
    return total;
  }

  double _reserveNet(
    List<TransferEntity> transfers,
    DateTime start,
    DateTime end,
  ) {
    var net = 0.0;
    for (final transfer in transfers) {
      if (!_contains(transfer.date, start, end)) continue;
      final into = transfer.fromType == WalletType.balance &&
          transfer.toType == WalletType.reserve;
      final out = transfer.fromType == WalletType.reserve &&
          transfer.toType == WalletType.balance;
      if (into) net += transfer.amount;
      if (out) net -= transfer.amount;
    }
    return net < 0 ? 0 : net;
  }

  double _reduction(double last) {
    final stepped = (_roundTo(last * 0.2, 10)).toDouble();
    if (stepped >= 20 && stepped < last) return stepped;
    if (20 < last) return 20;
    final half = _roundTo(last * 0.5, 10);
    return half > 0 && half < last ? half.toDouble() : last / 2;
  }

  double _storeTarget(double income) {
    if (income <= 0) return 100;
    var stepped = _roundTo(income * 0.1, 50).toDouble();
    if (stepped < 50) stepped = 50;
    if (stepped > 500) stepped = 500;
    return stepped;
  }

  int _roundTo(double value, int step) => (value / step).round() * step;

  DateTime _seasonStart(DateTime now) {
    final today = _date(now);
    final thisYear = DateTime(
      today.year,
      AnthillCatalog.winterMonth,
      AnthillCatalog.winterDay,
    );
    if (!today.isBefore(thisYear)) return thisYear;
    return DateTime(
      today.year - 1,
      AnthillCatalog.winterMonth,
      AnthillCatalog.winterDay,
    );
  }

  bool _weekEnded(DateTime now, DateTime sunday) {
    final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
    return !now.isBefore(end);
  }

  bool _contains(DateTime date, DateTime start, DateTime end) {
    final day = _date(date);
    return !day.isBefore(_date(start)) && !day.isAfter(_date(end));
  }

  bool _sameDay(DateTime date, DateTime day) => _date(date) == _date(day);

  DateTime _monday(DateTime day) {
    final date = _date(day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  DateTime _date(DateTime date) => DateTime(date.year, date.month, date.day);

  String _id(DateTime monday, WeeklyChallengeKind kind, String category) {
    final month = monday.month.toString().padLeft(2, '0');
    final day = monday.day.toString().padLeft(2, '0');
    return '${monday.year}-$month-$day-${kind.name}-$category';
  }

  String _money(double value) {
    final negative = value < 0;
    final cents = (value.abs() * 100).round();
    final whole = cents ~/ 100;
    final frac = cents % 100;
    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final body = frac == 0
        ? buffer.toString()
        : '$buffer,${frac.toString().padLeft(2, '0')}';
    return negative ? '-R\$ $body' : 'R\$ $body';
  }

  static const _stepDone = 'A formiga deu um passo na trilha do inverno.';
}

class _CategoryAmount {
  const _CategoryAmount(this.name, this.amount);

  final String name;
  final double amount;
}
