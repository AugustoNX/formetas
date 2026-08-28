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

  AnthillFacts copyWith({double? winterReadiness}) {
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

/// Missão do mês. Também é totalmente derivada dos dados financeiros, por isso
/// reinicia sozinha a cada mês, sem nada persistido.
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
  });

  final MissionDefinition definition;
  final double current;
  final double target;

  String get id => definition.id;

  bool get isComplete => target <= 0 || current >= target;

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble();

  double get remaining => (target - current).clamp(0, double.infinity);

  @override
  List<Object?> get props => [definition.id, current, target];
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
  });

  final DateTime nextWinter;
  final int daysRemaining;

  /// 0..1 — o quanto o formigueiro está preparado.
  final double readiness;

  final List<WinterTask> tasks;
  final String headline;
  final String message;

  int get readinessPercent => (readiness * 100).round();

  @override
  List<Object?> get props => [daysRemaining, readiness, tasks];
}

class AntEnergy extends Equatable {
  const AntEnergy({
    required this.level,
    required this.message,
  });

  /// 0 a [maxLevel]. É apenas visual: nunca bloqueia funcionalidade financeira.
  final int level;
  final String message;

  static const maxLevel = 5;

  @override
  List<Object?> get props => [level, message];
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

  /// Frase de abertura do formigueiro, sempre positiva.
  final String headline;

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
      ];
}
