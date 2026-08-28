import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/leaf_formatter.dart';
import '../../../core/utils/reserve_calculator.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../../domain/entities/goal_entity.dart';
import '../../../domain/entities/reserve_movement_entity.dart';
import '../../providers/data_providers.dart';
import '../formetas_card.dart';
import 'ant_character.dart';
import 'anthill_palette.dart';
import 'anthill_widgets.dart';

/// Blocos compartilhados entre as salas do formigueiro.
///
/// Cada um lê apenas providers já existentes: a leitura muda, os números não.

/// Retrato da formiga: nome, nível, folhinhas acumuladas e energia.
class AntSummaryCard extends StatelessWidget {
  const AntSummaryCard({super.key, required this.snapshot, this.onTap});

  final AnthillSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return FormetasCard(
      onTap: onTap ?? () => context.push('/formigueiro/formiga'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AntCharacter(
                level: snapshot.level.level,
                size: 96,
                animated: snapshot.profile.animationsEnabled,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.profile.antName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${snapshot.level.title} · Nível ${snapshot.level.level}',
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    AnthillProgressBar(value: snapshot.levelProgress),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.nextLevel == null
                          ? 'Nível máximo alcançado. Continue cuidando do formigueiro.'
                          : 'Faltam ${CurrencyFormatter.format(snapshot.remainingToNextLevel)} '
                              'para ${snapshot.nextLevel!.title}',
                      style: TextStyle(color: palette.muted, fontSize: 11.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: palette.muted.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LeafCounter(amount: snapshot.netWorth)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energia da formiga',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AntEnergyBar(energy: snapshot.energy),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Leitura do mês em folhinhas: coletadas, utilizadas e guardadas.
class LeafFlowCard extends StatelessWidget {
  const LeafFlowCard({super.key, required this.facts});

  final AnthillFacts facts;

  @override
  Widget build(BuildContext context) {
    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Folhinhas do mês',
            subtitle: 'A mesma leitura do seu mês, contada em folhinhas.',
          ),
          LeafFlowRow(facts: facts),
        ],
      ),
    );
  }
}

class WinterChecklistCard extends StatelessWidget {
  const WinterChecklistCard({super.key, required this.winter});

  final WinterStatus winter;

  @override
  Widget build(BuildContext context) {
    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Prepare seu formigueiro',
            subtitle: 'Pequenos passos que deixam o inverno mais tranquilo.',
          ),
          for (final task in winter.tasks) WinterTaskTile(task: task),
        ],
      ),
    );
  }
}

class MissionsSection extends StatelessWidget {
  const MissionsSection({super.key, required this.missions});

  final List<MissionStatus> missions;

  @override
  Widget build(BuildContext context) {
    final done = missions.where((m) => m.isComplete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnthillSectionHeader(
          title: 'Missões do mês',
          subtitle: '$done de ${missions.length} concluídas',
        ),
        for (final mission in missions) MissionTile(mission: mission),
      ],
    );
  }
}

/// Metas existentes apresentadas como grandes objetivos do formigueiro.
/// A tela de metas continua sendo a dona da regra: aqui só muda a leitura.
class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key, this.limit});

  /// Quantas metas mostrar. Sem limite, mostra todas.
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <GoalEntity>[];
    final palette = AnthillPalette.of(context);

    if (goals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnthillSectionHeader(
            title: 'Grandes objetivos',
            subtitle: 'Metas viram missões do formigueiro.',
          ),
          FormetasCard(
            onTap: () => context.push('/goal/new'),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: palette.glow),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Defina um objetivo e sua formiga saberá para onde levar '
                    'as folhinhas.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      );
    }

    final sorted = [...goals]..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.progressPercent.compareTo(a.progressPercent);
      });
    final visible = limit == null ? sorted : sorted.take(limit!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnthillSectionHeader(
          title: 'Grandes objetivos',
          subtitle: 'Metas viram missões do formigueiro.',
          action: TextButton.icon(
            onPressed: () => context.push('/goal/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nova'),
          ),
        ),
        for (final goal in visible) _GoalMissionTile(goal: goal),
      ],
    );
  }
}

class _GoalMissionTile extends StatelessWidget {
  const _GoalMissionTile({required this.goal});

  final GoalEntity goal;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final progress = goal.progressPercent / 100;
    final remaining = (goal.targetValue - goal.currentValue)
        .clamp(0, double.infinity)
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: FormetasCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('/goal/edit/${goal.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goal.isCompleted
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  size: 18,
                  color: goal.isCompleted ? palette.glow : palette.leaf,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Missão: ${goal.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${goal.progressPercent.round()}%',
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnthillProgressBar(
              value: progress,
              color: goal.isCompleted ? palette.glow : null,
            ),
            const SizedBox(height: 8),
            Text(
              goal.isCompleted
                  ? 'Missão concluída! Sua formiga conseguiu.'
                  : 'Faltam ${LeafFormatter.label(remaining)} '
                      '· ${CurrencyFormatter.format(remaining)}',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caixinhas apresentadas como armazéns. Os nomes e valores são os reais.
class StorageSection extends ConsumerWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserves = ref.watch(reservesWithMovementsProvider).valueOrNull ??
        const <ReserveWithMovements>[];
    final cdiRate = ref.watch(settingsProvider).valueOrNull?.cdiRate ?? 0;
    final palette = AnthillPalette.of(context);

    if (reserves.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnthillSectionHeader(
            title: 'Armazéns do formigueiro',
            subtitle: 'Cada caixinha guarda folhinhas para o inverno.',
          ),
          FormetasCard(
            onTap: () => context.push('/reserve/new'),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: palette.leaf),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Crie o primeiro armazém para começar a estocar folhinhas.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnthillSectionHeader(
          title: 'Armazéns do formigueiro',
          subtitle: '${reserves.length} guardando folhinhas',
          action: TextButton.icon(
            onPressed: () => context.push('/reserve/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Novo'),
          ),
        ),
        FormetasCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final item in reserves)
                _StorageTile(
                  name: item.reserve.name,
                  amount: ReserveCalculator.compute(
                    reserve: item.reserve,
                    movements: item.movements,
                    cdiRate: cdiRate,
                  ).currentValue,
                  onTap: () => context.push('/reserve/${item.reserve.id}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.name,
    required this.amount,
    required this.onTap,
  });

  final String name;
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.leaf.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 19,
                  color: palette.leaf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LeafFormatter.label(amount),
                      style: TextStyle(color: palette.muted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Investimentos lidos como folhinhas que trabalham sozinhas.
class WorkingLeavesCard extends StatelessWidget {
  const WorkingLeavesCard({super.key, required this.facts, this.onTap});

  final AnthillFacts facts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return FormetasCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.investment.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.investment,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Folhinhas trabalhando',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  facts.investments > 0
                      ? '${LeafFormatter.label(facts.investments)} rendendo por você'
                      : 'Coloque folhinhas para trabalhar e render.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            CurrencyFormatter.format(facts.investments),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Destaque da conquista mais próxima. Mostra o que vem a seguir sem cobrar.
class NextAchievementCard extends StatelessWidget {
  const NextAchievementCard({super.key, required this.achievement});

  final AchievementStatus achievement;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return FormetasCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.go('/formigueiro/conquistas'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.glow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              AntIcons.of(achievement.definition.icon),
              color: palette.glow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima conquista',
                  style: TextStyle(color: palette.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.definition.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                AnthillProgressBar(value: achievement.progress, height: 7),
                const SizedBox(height: 6),
                Text(
                  _remainingLabel(achievement),
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _remainingLabel(AchievementStatus achievement) {
    if (achievement.definition.unit == AnthillUnit.currency) {
      return 'Faltam ${CurrencyFormatter.format(achievement.remaining)}';
    }
    final remaining = achievement.remaining.round();
    return remaining <= 1 ? 'Falta pouco!' : 'Faltam $remaining';
  }
}

class AnthillErrorView extends StatelessWidget {
  const AnthillErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AntCharacter(level: 1, size: 110, animated: false),
            const SizedBox(height: 12),
            const Text(
              'O formigueiro está se organizando',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Não conseguimos carregar seus dados agora. '
              'Suas informações financeiras continuam seguras.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
