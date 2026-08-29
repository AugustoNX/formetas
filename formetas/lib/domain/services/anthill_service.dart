import '../../core/constants/anthill_catalog.dart';
import '../../core/utils/asset_calculator.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/monthly_balance_calculator.dart';
import '../../core/utils/patrimony_calculator.dart';
import '../entities/ant_profile_entity.dart';
import '../entities/anthill_snapshot.dart';
import '../entities/goal_entity.dart';
import '../entities/investment_entity.dart';
import '../entities/reserve_movement_entity.dart';
import '../entities/settings_entity.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';

/// Traduz os dados financeiros existentes na experiência do Formigueiro.
///
/// É uma camada de leitura: recebe as mesmas listas que alimentam o dashboard,
/// deriva fatos e devolve um [AnthillSnapshot]. Nunca escreve nada financeiro,
/// nunca recalcula saldo por conta própria (reaproveita os calculadores do
/// núcleo) e pode ser removida sem afetar o restante do aplicativo.
class AnthillService {
  const AnthillService();

  AnthillSnapshot buildSnapshot({
    required AntProfileEntity profile,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
    required List<GoalEntity> goals,
    required SettingsEntity settings,
    List<AssetPosition> positions = const [],
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    final baseFacts = _buildFacts(
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      positions: positions,
      goals: goals,
      settings: settings,
      now: now,
    );

    final level = AnthillCatalog.levelFor(baseFacts.netWorth);
    final nextLevel = AnthillCatalog.nextLevelAfter(level);

    final winter = _buildWinter(baseFacts, level, nextLevel, now);
    final facts = baseFacts.copyWith(winterReadiness: winter.readiness);

    return AnthillSnapshot(
      profile: profile,
      facts: facts,
      level: level,
      nextLevel: nextLevel,
      levelProgress: _levelProgress(facts.netWorth, level, nextLevel),
      winter: winter,
      energy: _buildEnergy(facts),
      achievements: _buildAchievements(facts, profile),
      missions: _buildMissions(facts),
      headline: _buildHeadline(facts, winter),
    );
  }

  // ---------------------------------------------------------------------------
  // Fatos
  // ---------------------------------------------------------------------------

  AnthillFacts _buildFacts({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
    required List<AssetPosition> positions,
    required List<GoalEntity> goals,
    required SettingsEntity settings,
    required DateTime now,
  }) {
    final patrimony = PatrimonyCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      reservesWithMovements: reserves,
      investments: investments,
      positions: positions,
      cdiRate: settings.cdiRate,
      until: now,
    );

    final summaries = MonthlyBalanceCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      fromMonth: PatrimonyCalculator.earliestMonth(transactions, transfers, now),
      toMonth: now,
    );

    final monthStart = AppDateUtils.startOfMonth(now);
    final monthEnd = AppDateUtils.endOfMonth(now);
    bool inCurrentMonth(DateTime date) =>
        !date.isBefore(monthStart) && !date.isAfter(monthEnd);

    final currentMonth = summaries.isEmpty ? null : summaries.last;

    final collectedAllTime = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.value);

    final usedAllTime = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.value);

    final monthTransactions =
        transactions.where((t) => inCurrentMonth(t.date)).toList();

    final expenseMonths =
        summaries.where((s) => s.expense > 0).map((s) => s.expense).toList();
    final averageMonthlyExpense = expenseMonths.isEmpty
        ? 0.0
        : expenseMonths.reduce((a, b) => a + b) / expenseMonths.length;

    return AnthillFacts(
      netWorth: patrimony.netWorth,
      balance: patrimony.balance,
      reserves: patrimony.reserves,
      investments: patrimony.investments,
      totalYield: patrimony.totalYield,
      collectedAllTime: collectedAllTime,
      usedAllTime: usedAllTime,
      collectedThisMonth: currentMonth?.income ?? 0,
      usedThisMonth: currentMonth?.expense ?? 0,
      savedThisMonth: currentMonth?.savings ?? 0,
      storedThisMonth: _storedAmount(
        transactions: monthTransactions,
        transfers: transfers.where((t) => inCurrentMonth(t.date)).toList(),
      ),
      averageMonthlyExpense: averageMonthlyExpense,
      transactionCount: transactions.length,
      transactionsThisMonth: monthTransactions.length,
      reserveCount: reserves.length,
      investmentCount: investments.length,
      goalCount: goals.length,
      completedGoalCount: goals.where((g) => g.isCompleted).length,
      monthsWithSavings: summaries.where((s) => s.savings > 0).length,
      savingStreak: _savingStreak(summaries),
      hasStoredEver: _hasStoredEver(
        transactions: transactions,
        transfers: transfers,
        reserves: reserves,
        investments: investments,
      ),
      daysSinceLastRecord: _daysSinceLastRecord(transactions, transfers, now),
    );
  }

  /// Folhinhas que saíram do saldo rumo aos armazéns e à área de investimentos.
  double _storedAmount({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
  }) {
    final out = transfers
        .where((t) =>
            t.fromType == WalletType.balance && t.toType != WalletType.balance)
        .fold(0.0, (sum, t) => sum + t.amount);

    final back = transfers
        .where((t) =>
            t.toType == WalletType.balance && t.fromType != WalletType.balance)
        .fold(0.0, (sum, t) => sum + t.amount);

    final invested = transactions
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (sum, t) => sum + t.value);

    final stored = out + invested - back;
    return stored < 0 ? 0 : stored;
  }

  bool _hasStoredEver({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
  }) {
    if (investments.isNotEmpty) return true;
    if (reserves.any((r) =>
        r.reserve.initialValue > 0 ||
        r.movements.any((m) => m.type == ReserveMovementType.deposit))) {
      return true;
    }
    if (transfers.any((t) =>
        t.fromType == WalletType.balance && t.toType != WalletType.balance)) {
      return true;
    }
    return transactions.any((t) => t.type == TransactionType.investment);
  }

  /// Meses seguidos guardando folhinhas.
  ///
  /// O mês corrente só interrompe a sequência quando já teve movimentação
  /// registrada: um mês que acabou de começar não tira o mérito do usuário.
  int _savingStreak(List<MonthlySummary> summaries) {
    if (summaries.isEmpty) return 0;

    var index = summaries.length - 1;
    final current = summaries[index];
    final currentIsUntouched =
        current.income == 0 && current.expense == 0 && current.investment == 0;
    if (currentIsUntouched) index--;

    var streak = 0;
    while (index >= 0 && summaries[index].savings > 0) {
      streak++;
      index--;
    }
    return streak;
  }

  int _daysSinceLastRecord(
    List<TransactionEntity> transactions,
    List<TransferEntity> transfers,
    DateTime now,
  ) {
    final dates = <DateTime>[
      ...transactions.map((t) => t.date),
      ...transfers.map((t) => t.date),
    ];
    if (dates.isEmpty) return 9999;
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final days = now.difference(latest).inDays;
    return days < 0 ? 0 : days;
  }

  // ---------------------------------------------------------------------------
  // Níveis
  // ---------------------------------------------------------------------------

  double _levelProgress(double netWorth, AntLevel level, AntLevel? nextLevel) {
    if (nextLevel == null) return 1;
    final span = nextLevel.threshold - level.threshold;
    if (span <= 0) return 1;
    return ((netWorth - level.threshold) / span).clamp(0, 1).toDouble();
  }

  // ---------------------------------------------------------------------------
  // Inverno
  // ---------------------------------------------------------------------------

  WinterStatus _buildWinter(
    AnthillFacts facts,
    AntLevel level,
    AntLevel? nextLevel,
    DateTime now,
  ) {
    final reserveTarget = _reserveTarget(facts);

    final tasks = <WinterTask>[
      WinterTask(
        title: 'Guardar ${AnthillCatalog.winterMonthsOfExpenses} meses de folhinhas',
        current: facts.reserves + facts.investments,
        target: reserveTarget,
        unit: AnthillUnit.currency,
        weight: 3,
      ),
      WinterTask(
        title: 'Manter ${AnthillCatalog.winterStorageTarget} armazéns no formigueiro',
        current: facts.reserveCount.toDouble(),
        target: AnthillCatalog.winterStorageTarget.toDouble(),
        unit: AnthillUnit.count,
      ),
      WinterTask(
        title: '${AnthillCatalog.winterStreakTarget} meses seguidos guardando',
        current: facts.savingStreak.toDouble(),
        target: AnthillCatalog.winterStreakTarget.toDouble(),
        unit: AnthillUnit.count,
      ),
      if (nextLevel != null)
        WinterTask(
          title: 'Chegar a ${nextLevel.threshold.round()} folhinhas',
          current: facts.netWorth,
          target: nextLevel.threshold,
          unit: AnthillUnit.currency,
        )
      else
        WinterTask(
          title: 'Manter o grande formigueiro',
          current: facts.netWorth,
          target: level.threshold,
          unit: AnthillUnit.currency,
        ),
    ];

    final totalWeight = tasks.fold(0.0, (sum, t) => sum + t.weight);
    final readiness = totalWeight <= 0
        ? 0.0
        : tasks.fold(0.0, (sum, t) => sum + t.progress * t.weight) / totalWeight;

    final nextWinter = _nextWinter(now);

    return WinterStatus(
      nextWinter: nextWinter,
      daysRemaining: nextWinter.difference(_atMidnight(now)).inDays,
      readiness: readiness,
      tasks: tasks,
      headline: 'O inverno está chegando',
      message: _winterMessage(readiness),
    );
  }

  double _reserveTarget(AnthillFacts facts) {
    final byExpenses =
        facts.averageMonthlyExpense * AnthillCatalog.winterMonthsOfExpenses;
    return byExpenses < AnthillCatalog.winterMinimumTarget
        ? AnthillCatalog.winterMinimumTarget
        : byExpenses;
  }

  String _winterMessage(double readiness) {
    if (readiness >= 0.85) {
      return 'Seu formigueiro está bem preparado. Que orgulho dessa formiga.';
    }
    if (readiness >= 0.6) {
      return 'Você está no caminho certo. O formigueiro está ficando seguro.';
    }
    if (readiness >= 0.3) {
      return 'Mais algumas folhinhas e sua formiga estará bem mais tranquila.';
    }
    if (readiness > 0) {
      return 'O começo já aconteceu. Cada folhinha guardada conta.';
    }
    return 'Uma folhinha já é melhor que nenhuma. Vamos começar juntos?';
  }

  DateTime _nextWinter(DateTime now) {
    final today = _atMidnight(now);
    final thisYear =
        DateTime(today.year, AnthillCatalog.winterMonth, AnthillCatalog.winterDay);
    if (!thisYear.isBefore(today)) return thisYear;
    return DateTime(
      today.year + 1,
      AnthillCatalog.winterMonth,
      AnthillCatalog.winterDay,
    );
  }

  DateTime _atMidnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  // ---------------------------------------------------------------------------
  // Energia
  // ---------------------------------------------------------------------------

  AntEnergy _buildEnergy(AnthillFacts facts) {
    var level = 0;
    if (facts.transactionsThisMonth > 0 || facts.daysSinceLastRecord <= 15) {
      level++;
    }
    if (facts.savedThisMonth > 0 || facts.storedThisMonth > 0) level++;
    if (facts.reserveCount > 0) level++;
    if (facts.investments > 0) level++;
    if (facts.savingStreak >= 2) level++;

    return AntEnergy(level: level, message: _energyMessage(level));
  }

  String _energyMessage(int level) => switch (level) {
        >= 5 => 'Sua formiga está cheia de energia!',
        4 => 'Sua formiga está animada com o ritmo.',
        3 => 'Sua formiga está trabalhando com constância.',
        2 => 'Sua formiga está aquecendo os motores.',
        1 => 'Sua formiga acabou de sair para a trilha.',
        _ => 'Sua formiga está descansando, pronta para recomeçar.',
      };

  // ---------------------------------------------------------------------------
  // Conquistas e missões
  // ---------------------------------------------------------------------------

  List<AchievementStatus> _buildAchievements(
    AnthillFacts facts,
    AntProfileEntity profile,
  ) {
    return [
      for (final definition in AnthillCatalog.achievements)
        AchievementStatus(
          definition: definition,
          current: definition.value(facts),
          target: definition.target(facts),
          unlockedAt: profile.unlockedAt(definition.id),
        ),
    ];
  }

  List<MissionStatus> _buildMissions(AnthillFacts facts) {
    final missions = [
      for (final definition in AnthillCatalog.missions)
        MissionStatus(
          definition: definition,
          current: definition.value(facts),
          target: definition.target(facts),
        ),
    ];

    // Missões pendentes primeiro, preservando a ordem do catálogo dentro de
    // cada grupo, para que o usuário veja logo o que ainda pode fazer.
    final pending = missions.where((m) => !m.isComplete).toList();
    final done = missions.where((m) => m.isComplete).toList();
    return [...pending, ...done];
  }

  // ---------------------------------------------------------------------------
  // Narrativa
  // ---------------------------------------------------------------------------

  String _buildHeadline(AnthillFacts facts, WinterStatus winter) {
    if (facts.transactionCount == 0) {
      return 'Seu formigueiro acabou de nascer. Vamos buscar a primeira folhinha?';
    }
    if (facts.netWorth <= 0) {
      return 'Sua formiga está trabalhando. Toda folhinha conta.';
    }
    if (facts.storedThisMonth > 0) {
      return 'Novas folhinhas chegaram ao formigueiro este mês.';
    }
    if (facts.savedThisMonth > 0) {
      return 'Está ficando cada vez maior.';
    }
    if (winter.readiness >= 0.85) {
      return 'Um formigueiro forte, construído folhinha por folhinha.';
    }
    if (facts.savingStreak >= 2) {
      return 'Trabalho de formiguinha: constante e sem pressa.';
    }
    return 'Sua formiga continua cuidando do que você já construiu.';
  }
}
