import '../../domain/entities/anthill_snapshot.dart';

/// Configuração da experiência gamificada.
///
/// Tudo aqui é ajustável sem tocar em nenhuma regra financeira: níveis,
/// conquistas, missões e os parâmetros do inverno.
abstract final class AnthillCatalog {
  /// Quantos meses de despesa média o formigueiro precisa guardar para
  /// atravessar o inverno tranquilo.
  static const winterMonthsOfExpenses = 6;

  /// Piso usado quando ainda não há histórico de despesas suficiente.
  static const winterMinimumTarget = 1000.0;

  /// Quantos armazéns (caixinhas) o formigueiro ideal mantém.
  static const winterStorageTarget = 3;

  /// Meses seguidos guardando folhinhas que caracterizam consistência.
  static const winterStreakTarget = 3;

  /// Data simbólica do inverno (hemisfério sul). O ciclo se repete todo ano.
  static const winterMonth = 6;
  static const winterDay = 21;

  /// Evolução da formiga por patrimônio. A ordem crescente é obrigatória.
  static const List<AntLevel> levels = [
    AntLevel(
      level: 1,
      title: 'Formiga Iniciante',
      subtitle: 'Toda folhinha conta. O começo já é uma conquista.',
      threshold: 0,
    ),
    AntLevel(
      level: 2,
      title: 'Formiga Trabalhadora',
      subtitle: 'Sua formiga já carrega folhinhas todos os dias.',
      threshold: 1000,
    ),
    AntLevel(
      level: 3,
      title: 'Formiga Dedicada',
      subtitle: 'O formigueiro ganhou novos túneis e salas.',
      threshold: 5000,
    ),
    AntLevel(
      level: 4,
      title: 'Guardiã do Formigueiro',
      subtitle: 'Um formigueiro sólido, pronto para proteger a colônia.',
      threshold: 10000,
    ),
    AntLevel(
      level: 5,
      title: 'Rainha do Formigueiro',
      subtitle: 'Um grande formigueiro construído folhinha por folhinha.',
      threshold: 25000,
    ),
  ];

  static AntLevel levelFor(double netWorth) {
    var current = levels.first;
    for (final level in levels) {
      if (netWorth >= level.threshold) current = level;
    }
    return current;
  }

  static AntLevel? nextLevelAfter(AntLevel level) {
    final index = levels.indexWhere((l) => l.level == level.level);
    if (index < 0 || index >= levels.length - 1) return null;
    return levels[index + 1];
  }

  /// Conquistas. Cada regra apenas lê os fatos financeiros já calculados.
  static const List<AchievementDefinition> achievements = [
    AchievementDefinition(
      id: 'primeira_folhinha',
      title: 'Primeira Folhinha',
      description: 'Você registrou sua primeira movimentação.',
      lockedHint: 'Registre sua primeira movimentação.',
      icon: AntIcon.leaf,
      unit: AnthillUnit.count,
      value: _transactionCount,
      target: _one,
    ),
    AchievementDefinition(
      id: 'formiga_trabalhadora',
      title: 'Formiga Trabalhadora',
      description: 'Você guardou folhinhas pela primeira vez.',
      lockedHint: 'Leve folhinhas do saldo para uma caixinha.',
      icon: AntIcon.ant,
      unit: AnthillUnit.count,
      value: _storedEver,
      target: _one,
    ),
    AchievementDefinition(
      id: 'guardia_da_reserva',
      title: 'Guardiã da Reserva',
      description: 'Seu formigueiro ganhou o primeiro armazém.',
      lockedHint: 'Crie sua primeira caixinha.',
      icon: AntIcon.storage,
      unit: AnthillUnit.count,
      value: _reserveCount,
      target: _one,
    ),
    AchievementDefinition(
      id: 'investidor_formiga',
      title: 'Investidor Formiga',
      description: 'Você colocou folhinhas para trabalhar.',
      lockedHint: 'Faça seu primeiro investimento.',
      icon: AntIcon.invest,
      unit: AnthillUnit.count,
      value: _investmentCount,
      target: _one,
    ),
    AchievementDefinition(
      id: 'sonho_no_horizonte',
      title: 'Sonho no Horizonte',
      description: 'Você definiu um objetivo para o formigueiro.',
      lockedHint: 'Crie sua primeira meta.',
      icon: AntIcon.target,
      unit: AnthillUnit.count,
      value: _goalCount,
      target: _one,
    ),
    AchievementDefinition(
      id: 'pequeno_formigueiro',
      title: 'Pequeno Formigueiro',
      description: 'Seu patrimônio chegou a 1.000 folhinhas.',
      lockedHint: 'Alcance 1.000 folhinhas de patrimônio.',
      icon: AntIcon.anthill,
      unit: AnthillUnit.currency,
      value: _netWorth,
      target: _thousand,
    ),
    AchievementDefinition(
      id: 'tres_armazens',
      title: 'Formigueiro Organizado',
      description: 'Três armazéns cuidando das suas folhinhas.',
      lockedHint: 'Mantenha 3 caixinhas ativas.',
      icon: AntIcon.storage,
      unit: AnthillUnit.count,
      value: _reserveCount,
      target: _three,
    ),
    AchievementDefinition(
      id: 'formiga_persistente',
      title: 'Formiga Persistente',
      description: 'Você guardou folhinhas em 5 meses diferentes.',
      lockedHint: 'Feche 5 meses no positivo.',
      icon: AntIcon.streak,
      unit: AnthillUnit.count,
      value: _monthsWithSavings,
      target: _five,
    ),
    AchievementDefinition(
      id: 'trilha_constante',
      title: 'Trilha Constante',
      description: 'Três meses seguidos levando folhinhas para casa.',
      lockedHint: 'Guarde folhinhas em 3 meses seguidos.',
      icon: AntIcon.streak,
      unit: AnthillUnit.count,
      value: _savingStreak,
      target: _three,
    ),
    AchievementDefinition(
      id: 'formigueiro_crescendo',
      title: 'Formigueiro Crescendo',
      description: 'Seu patrimônio chegou a 5.000 folhinhas.',
      lockedHint: 'Alcance 5.000 folhinhas de patrimônio.',
      icon: AntIcon.anthill,
      unit: AnthillUnit.currency,
      value: _netWorth,
      target: _fiveThousand,
    ),
    AchievementDefinition(
      id: 'folhinhas_trabalhando',
      title: 'Folhinhas Trabalhando',
      description: 'Você tem 1.000 folhinhas rendendo por você.',
      lockedHint: 'Mantenha 1.000 folhinhas investidas.',
      icon: AntIcon.invest,
      unit: AnthillUnit.currency,
      value: _investments,
      target: _thousand,
    ),
    AchievementDefinition(
      id: 'jardim_rendendo',
      title: 'Jardim Rendendo',
      description: 'Suas folhinhas já geraram 100 novas folhinhas.',
      lockedHint: 'Acumule R\$ 100 em rendimentos.',
      icon: AntIcon.sprout,
      unit: AnthillUnit.currency,
      value: _totalYield,
      target: _hundred,
    ),
    AchievementDefinition(
      id: 'missao_cumprida',
      title: 'Missão Cumprida',
      description: 'Você concluiu uma meta do formigueiro.',
      lockedHint: 'Conclua sua primeira meta.',
      icon: AntIcon.trophy,
      unit: AnthillUnit.count,
      value: _completedGoals,
      target: _one,
    ),
    AchievementDefinition(
      id: 'colheita_farta',
      title: 'Colheita Farta',
      description: 'Você já coletou 10.000 folhinhas ao longo do tempo.',
      lockedHint: 'Some R\$ 10.000 em receitas registradas.',
      icon: AntIcon.harvest,
      unit: AnthillUnit.currency,
      value: _collectedAllTime,
      target: _tenThousand,
    ),
    AchievementDefinition(
      id: 'semeadora',
      title: 'Semeadora',
      description: 'Cinquenta movimentações registradas com carinho.',
      lockedHint: 'Registre 50 movimentações.',
      icon: AntIcon.leaf,
      unit: AnthillUnit.count,
      value: _transactionCount,
      target: _fifty,
    ),
    AchievementDefinition(
      id: 'preparado_para_o_inverno',
      title: 'Preparada para o Inverno',
      description: 'Seu formigueiro está pronto para a estação fria.',
      lockedHint: 'Complete a preparação para o inverno.',
      icon: AntIcon.snowflake,
      unit: AnthillUnit.count,
      value: _winterReadiness,
      target: _one,
    ),
    AchievementDefinition(
      id: 'formigueiro_forte',
      title: 'Formigueiro Forte',
      description: 'Seu patrimônio chegou a 10.000 folhinhas.',
      lockedHint: 'Alcance 10.000 folhinhas de patrimônio.',
      icon: AntIcon.anthill,
      unit: AnthillUnit.currency,
      value: _netWorth,
      target: _tenThousand,
    ),
    AchievementDefinition(
      id: 'grande_formigueiro',
      title: 'Grande Formigueiro',
      description: 'Um formigueiro de 25.000 folhinhas. Que jornada!',
      lockedHint: 'Alcance 25.000 folhinhas de patrimônio.',
      icon: AntIcon.star,
      unit: AnthillUnit.currency,
      value: _netWorth,
      target: _twentyFiveThousand,
    ),
  ];

  /// Missões do mês, recalculadas a partir dos dados reais.
  static const List<MissionDefinition> missions = [
    MissionDefinition(
      id: 'guardar_no_mes',
      title: 'Levar folhinhas ao armazém',
      description: 'Transfira parte do saldo para uma caixinha ou investimento.',
      icon: AntIcon.storage,
      unit: AnthillUnit.currency,
      value: _storedThisMonth,
      target: _monthlyStorageTarget,
    ),
    MissionDefinition(
      id: 'fechar_mes_positivo',
      title: 'Fechar o mês economizando',
      description: 'Termine o mês com mais folhinhas do que começou.',
      icon: AntIcon.leaf,
      unit: AnthillUnit.currency,
      value: _savedThisMonth,
      target: _monthlySavingTarget,
    ),
    MissionDefinition(
      id: 'registrar_movimentacoes',
      title: 'Anotar a trilha do mês',
      description: 'Registre 5 movimentações para acompanhar seu formigueiro.',
      icon: AntIcon.ant,
      unit: AnthillUnit.count,
      value: _transactionsThisMonth,
      target: _five,
    ),
    MissionDefinition(
      id: 'manter_armazem',
      title: 'Manter um armazém ativo',
      description: 'Uma caixinha guardando folhinhas para o inverno.',
      icon: AntIcon.snowflake,
      unit: AnthillUnit.count,
      value: _reserveCount,
      target: _one,
    ),
    MissionDefinition(
      id: 'objetivo_em_andamento',
      title: 'Ter um objetivo em andamento',
      description: 'Uma meta dá direção para as folhinhas do formigueiro.',
      icon: AntIcon.target,
      unit: AnthillUnit.count,
      value: _goalCount,
      target: _one,
    ),
  ];
}

// As funções abaixo existem apenas para permitir catálogos `const`.

double _one(AnthillFacts _) => 1;
double _three(AnthillFacts _) => 3;
double _five(AnthillFacts _) => 5;
double _fifty(AnthillFacts _) => 50;
double _hundred(AnthillFacts _) => 100;
double _thousand(AnthillFacts _) => 1000;
double _fiveThousand(AnthillFacts _) => 5000;
double _tenThousand(AnthillFacts _) => 10000;
double _twentyFiveThousand(AnthillFacts _) => 25000;

double _netWorth(AnthillFacts f) => f.netWorth;
double _investments(AnthillFacts f) => f.investments;
double _totalYield(AnthillFacts f) => f.totalYield;
double _collectedAllTime(AnthillFacts f) => f.collectedAllTime;
double _transactionCount(AnthillFacts f) => f.transactionCount.toDouble();
double _transactionsThisMonth(AnthillFacts f) =>
    f.transactionsThisMonth.toDouble();
double _reserveCount(AnthillFacts f) => f.reserveCount.toDouble();
double _investmentCount(AnthillFacts f) => f.investmentCount.toDouble();
double _goalCount(AnthillFacts f) => f.goalCount.toDouble();
double _completedGoals(AnthillFacts f) => f.completedGoalCount.toDouble();
double _monthsWithSavings(AnthillFacts f) => f.monthsWithSavings.toDouble();
double _savingStreak(AnthillFacts f) => f.savingStreak.toDouble();
double _storedEver(AnthillFacts f) => f.hasStoredEver ? 1 : 0;
double _winterReadiness(AnthillFacts f) => f.winterReadiness;
double _storedThisMonth(AnthillFacts f) => f.storedThisMonth;
double _savedThisMonth(AnthillFacts f) => f.savedThisMonth;

/// Alvo mensal de folhinhas guardadas: 10% da despesa média, com piso de R$ 100.
double _monthlyStorageTarget(AnthillFacts f) {
  final suggested = f.averageMonthlyExpense * 0.1;
  return suggested < 100 ? 100 : _roundToNearest(suggested, 50);
}

/// Alvo mensal de economia: 5% da despesa média, com piso de R$ 50.
double _monthlySavingTarget(AnthillFacts f) {
  final suggested = f.averageMonthlyExpense * 0.05;
  return suggested < 50 ? 50 : _roundToNearest(suggested, 50);
}

double _roundToNearest(double value, double step) =>
    (value / step).roundToDouble() * step;
