import 'package:equatable/equatable.dart';

import 'ant_profile_entity.dart';

/// Ícones da experiência gamificada. O domínio não conhece Flutter; a camada
/// de apresentação traduz cada valor em um `IconData`.
enum AntIcon {
  leaf,
  ant,
  anthill,
  storage,
  invest,
  trophy,
  snowflake,
  target,
  streak,
  star,
  harvest,
  sprout,
}

/// Como o progresso deve ser lido: em reais ou em contagem.
enum AnthillUnit { currency, count }

class AntLevel extends Equatable {
  const AntLevel({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.threshold,
  });

  final int level;
  final String title;
  final String subtitle;

  /// Patrimônio mínimo (em R$) para alcançar o nível.
  final double threshold;

  @override
  List<Object?> get props => [level, title, threshold];
}

/// Retrato dos dados financeiros reais no momento da consulta.
///
/// É a única entrada da gamificação. Nenhum valor daqui é gravado de volta:
/// tudo é derivado das transações, transferências, caixinhas, investimentos e
/// metas que já existem.
class AnthillFacts extends Equatable {
  const AnthillFacts({
    required this.netWorth,
    required this.balance,
    required this.reserves,
    required this.investments,
    required this.totalYield,
    required this.collectedAllTime,
    required this.usedAllTime,
    required this.collectedThisMonth,
    required this.usedThisMonth,
    required this.savedThisMonth,
    required this.storedThisMonth,
    required this.averageMonthlyExpense,
    required this.transactionCount,
    required this.transactionsThisMonth,
    required this.reserveCount,
    required this.investmentCount,
    required this.goalCount,
    required this.completedGoalCount,
    required this.monthsWithSavings,
    required this.savingStreak,
    required this.hasStoredEver,
    required this.daysSinceLastRecord,
    this.winterReadiness = 0,
    this.winterArrival = false,
  });

  final double netWorth;
  final double balance;
  final double reserves;
  final double investments;
  final double totalYield;

  final double collectedAllTime;
  final double usedAllTime;
  final double collectedThisMonth;
  final double usedThisMonth;
  final double savedThisMonth;

  /// Quanto saiu do saldo para caixinhas/investimentos neste mês.
  final double storedThisMonth;

  final double averageMonthlyExpense;

  final int transactionCount;
  final int transactionsThisMonth;
  final int reserveCount;
  final int investmentCount;
  final int goalCount;
  final int completedGoalCount;
  final int monthsWithSavings;
  final int savingStreak;

  final bool hasStoredEver;
  final int daysSinceLastRecord;

  final double winterReadiness;

  /// Verdadeiro só na janela do inverno, quando a despensa cobre a meta.
  final bool winterArrival;

  AnthillFacts copyWith({
    double? winterReadiness,
    bool? winterArrival,
  }) {
    return AnthillFacts(
      netWorth: netWorth,
      balance: balance,
      reserves: reserves,
      investments: investments,
      totalYield: totalYield,
      collectedAllTime: collectedAllTime,
      usedAllTime: usedAllTime,
      collectedThisMonth: collectedThisMonth,
      usedThisMonth: usedThisMonth,
      savedThisMonth: savedThisMonth,
      storedThisMonth: storedThisMonth,
      averageMonthlyExpense: averageMonthlyExpense,
      transactionCount: transactionCount,
      transactionsThisMonth: transactionsThisMonth,
      reserveCount: reserveCount,
      investmentCount: investmentCount,
      goalCount: goalCount,
      completedGoalCount: completedGoalCount,
      monthsWithSavings: monthsWithSavings,
      savingStreak: savingStreak,
      hasStoredEver: hasStoredEver,
      daysSinceLastRecord: daysSinceLastRecord,
      winterReadiness: winterReadiness ?? this.winterReadiness,
      winterArrival: winterArrival ?? this.winterArrival,
    );
  }

  @override
  List<Object?> get props => [
        netWorth,
        balance,
        reserves,
        investments,
        collectedThisMonth,
        usedThisMonth,
        storedThisMonth,
        transactionCount,
        reserveCount,
        investmentCount,
        goalCount,
        completedGoalCount,
        savingStreak,
        winterReadiness,
        winterArrival,
      ];
}

/// Regra de uma conquista: lê os fatos e devolve progresso atual e alvo.
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.lockedHint,
    required this.icon,
    required this.unit,
    required this.value,
    required this.target,
  });

  final String id;
  final String title;
  final String description;

  /// Texto exibido enquanto a conquista está bloqueada.
  final String lockedHint;

  final AntIcon icon;
  final AnthillUnit unit;
  final double Function(AnthillFacts facts) value;
  final double Function(AnthillFacts facts) target;
}

class AchievementStatus extends Equatable {
  const AchievementStatus({
    required this.definition,
    required this.current,
    required this.target,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final double current;
  final double target;
  final DateTime? unlockedAt;

  String get id => definition.id;

  bool get isEarned => target <= 0 || current >= target;

  bool get isUnlocked => unlockedAt != null || isEarned;

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble();

  double get remaining => (target - current).clamp(0, double.infinity);

  @override
  List<Object?> get props => [definition.id, current, target, unlockedAt];
}

/// Forma compartilhada por uma missão derivada dos lançamentos.
class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unit,
    required this.value,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final AntIcon icon;
  final AnthillUnit unit;
  final double Function(AnthillFacts facts) value;
  final double Function(AnthillFacts facts) target;
}

class MissionStatus extends Equatable {
  const MissionStatus({
    required this.definition,
    required this.current,
    required this.target,
    this.settled,
    this.progressLabel,
  });

  final MissionDefinition definition;
  final double current;
  final double target;

  /// Quando definido, substitui a comparação `current >= target`.
  final bool? settled;

  final String? progressLabel;

  String get id => definition.id;

  bool get isComplete => settled ?? (target <= 0 || current >= target);

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble();

  double get remaining => (target - current).clamp(0, double.infinity);

  @override
  List<Object?> get props => [definition.id, current, target, settled, progressLabel];
}

class WinterTask extends Equatable {
  const WinterTask({
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    this.weight = 1,
  });

  final String title;
  final double current;
  final double target;
  final AnthillUnit unit;
  final double weight;

  bool get isDone => target <= 0 || current >= target;

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [title, current, target, weight];
}

class WinterStatus extends Equatable {
  const WinterStatus({
    required this.nextWinter,
    required this.daysRemaining,
    required this.readiness,
    required this.tasks,
    required this.headline,
    required this.message,
    required this.monthsCovered,
    required this.spendingKnown,
    required this.pantry,
    required this.showScene,
    required this.shelterReady,
    required this.trailSteps,
  });

  final DateTime nextWinter;
  final int daysRemaining;

  /// 0..1 — o quanto o formigueiro está preparado.
  final double readiness;

  final List<WinterTask> tasks;
  final String headline;
  final String message;

  /// Reservas e investimentos divididos pela despesa média mensal.
  final double monthsCovered;

  final bool spendingKnown;
  final String pantry;

  /// Janela em que o inverno tem desfecho, em vez de só uma contagem.
  final bool showScene;

  final bool shelterReady;
  final int trailSteps;

  int get readinessPercent => (readiness * 100).round();

  String get stepsLabel => trailSteps == 1
      ? '1 passo na trilha do inverno'
      : '$trailSteps passos na trilha do inverno';

  @override
  List<Object?> get props => [
        daysRemaining,
        readiness,
        tasks,
        monthsCovered,
        showScene,
        shelterReady,
        trailSteps,
      ];
}

enum AntMood { tired, calm, fed, asleep }

enum AnthillGround { growing, warm, thin }

class AntEnergy extends Equatable {
  const AntEnergy({
    required this.level,
    required this.message,
  });

  /// 0 a [maxLevel]. É apenas visual: nunca bloqueia funcionalidade financeira.
  final int level;
  final String message;

  static const maxLevel = 5;

  AntMood get mood => switch (level) {
        >= 4 => AntMood.fed,
        <= 1 => AntMood.tired,
        _ => AntMood.calm,
      };

  @override
  List<Object?> get props => [level, message];
}

enum WeeklyChallengeKind { spendLess, store, pause }

class WeeklyChallenge extends Equatable {
  const WeeklyChallenge({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.icon,
    required this.unit,
    required this.current,
    required this.target,
    required this.isComplete,
    required this.progressLabel,
    this.category = '',
  });

  final String id;
  final WeeklyChallengeKind kind;
  final String title;
  final String detail;
  final AntIcon icon;
  final AnthillUnit unit;
  final double current;
  final double target;
  final bool isComplete;
  final String progressLabel;
  final String category;

  bool get stopped => !isComplete && target > 0 && current > target;

  double get progress {
    if (isComplete) return 1;
    if (target <= 0) return 0;
    return (current / target).clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [id, current, target, isComplete, title];
}

class SpendingTrail extends Equatable {
  const SpendingTrail({
    required this.category,
    required this.startedOn,
    required this.days,
    required this.finished,
  });

  static const length = 7;

  static const inactive = SpendingTrail(
    category: null,
    startedOn: null,
    days: [null, null, null, null, null, null, null],
    finished: false,
  );

  final String? category;
  final DateTime? startedOn;

  /// `true` dia limpo, `false` dia com gasto, `null` dia que ainda não chegou.
  final List<bool?> days;
  final bool finished;

  bool get active =>
      category != null && category!.isNotEmpty && startedOn != null;

  int get steps => days.where((day) => day == true).length;

  bool get arrived =>
      active && days.length == length && days.every((day) => day == true);

  @override
  List<Object?> get props => [category, startedOn, days, finished];
}

/// Estado completo do Formigueiro em um instante.
class AnthillSnapshot extends Equatable {
  const AnthillSnapshot({
    required this.profile,
    required this.facts,
    required this.level,
    required this.nextLevel,
    required this.levelProgress,
    required this.winter,
    required this.energy,
    required this.achievements,
    required this.missions,
    required this.challenge,
    required this.trail,
    required this.weeklyNote,
    required this.headline,
  });

  final AntProfileEntity profile;
  final AnthillFacts facts;
  final AntLevel level;
  final AntLevel? nextLevel;

  /// Progresso dentro do nível atual (0..1).
  final double levelProgress;

  final WinterStatus winter;
  final AntEnergy energy;
  final List<AchievementStatus> achievements;
  final List<MissionStatus> missions;
  final WeeklyChallenge challenge;
  final SpendingTrail trail;

  /// Uma ou duas frases com o gasto e o que foi para o armazém nesta semana.
  final String weeklyNote;

  /// Frase de abertura do formigueiro, sempre positiva.
  final String headline;

  AntMood get antMood {
    if (winter.showScene && winter.shelterReady) return AntMood.asleep;
    return energy.mood;
  }

  AnthillGround get ground {
    if (!winter.showScene) return AnthillGround.growing;
    return winter.shelterReady ? AnthillGround.warm : AnthillGround.thin;
  }

  /// Folhinhas = patrimônio construído. R$ 1 equivale a 1 folhinha.
  int get leaves => facts.netWorth <= 0 ? 0 : facts.netWorth.round();

  double get netWorth => facts.netWorth;

  List<AchievementStatus> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();

  int get unlockedCount => unlockedAchievements.length;

  int get achievementCount => achievements.length;

  /// Próxima conquista mais perto de ser alcançada.
  AchievementStatus? get nextAchievement {
    final pending = achievements.where((a) => !a.isUnlocked).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    return pending.isEmpty ? null : pending.first;
  }

  double get remainingToNextLevel {
    final next = nextLevel;
    if (next == null) return 0;
    return (next.threshold - facts.netWorth).clamp(0, double.infinity);
  }

  @override
  List<Object?> get props => [
        profile,
        facts,
        level,
        winter,
        energy,
        achievements,
        missions,
        challenge,
        trail,
        weeklyNote,
      ];
}
