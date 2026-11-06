import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/control_trail.dart';
import '../../../domain/entities/insight.dart';
import '../../providers/data_providers.dart';
import '../../providers/insight_providers.dart';
import '../../widgets/formetas_card.dart';
import '../../widgets/insights/control_trail_card.dart';
import '../../widgets/insights/insight_card.dart';
import '../../widgets/insights/trail_proposal_sheet.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  /// Escondidos na hora (antes do RTDB confirmar), exigência do Dismissible.
  final _hidden = <String>{};

  void _dismiss(Insight insight) {
    setState(() => _hidden.add(insight.id));
    _guard(context, () => ref.read(insightActionsProvider).dismiss(insight), null);
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(insightsProvider);
    final trails = ref.watch(activeTrailsProgressProvider);
    final dismissedCount = ref.watch(dismissedInsightsProvider).valueOrNull?.length ?? 0;
    final now = ref.watch(insightClockProvider)();
    final actions = ref.read(insightActionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights da formiguinha'),
        actions: [
          if (dismissedCount > 0)
            IconButton(
              tooltip: 'Mostrar dispensados ($dismissedCount)',
              icon: const Icon(Icons.restore_rounded),
              onPressed: () {
                setState(_hidden.clear);
                _guard(context, actions.restoreDismissed, 'Insights restaurados');
              },
            ),
        ],
      ),
      body: insights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível gerar os insights.\n$e')),
        data: (all) {
          final list = all.where((i) => !_hidden.contains(i.id)).toList();
          return RefreshIndicator(
          onRefresh: () async => ref.invalidate(transactionsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (trails.isNotEmpty) ...[
                _SectionTitle('Trilhas em andamento', theme),
                for (final p in trails)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ControlTrailCard(
                      progress: p,
                      now: now,
                      onAbandon: () => _confirmAbandon(context, () => actions.abandonTrail(p.trail)),
                      onComplete: () => _guard(
                        context,
                        () => actions.completeTrail(p.trail),
                        'Trilha concluída: ${p.metCount}/${p.trail.weeks} semanas na meta 🐜',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              _SectionTitle('O que a formiguinha notou', theme),
              _PeriodCaption(now),
              if (list.isEmpty)
                const _EmptyState()
              else
                for (final (i, insight) in list.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InsightCard(
                      insight: insight,
                      initiallyExpanded: i == 0,
                      onDismiss: () => _dismiss(insight),
                      onAction: insight.action == null
                          ? null
                          : () => _runAction(context, insight),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 250.ms, delay: (40 * i).ms)
                      .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 8),
              Text(
                'O mês atual do cálculo é o calendário de hoje, não o filtro do dashboard. '
                'Toque num card para ver detalhes; deslize para dispensar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.gray),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  Future<void> _runAction(BuildContext context, Insight insight) async {
    final action = insight.action!;
    switch (action.type) {
      case InsightActionType.openTransactions:
        context.go('/transactions');
      case InsightActionType.openGoals:
        context.go('/goals');
      case InsightActionType.createTrail:
        final actions = ref.read(insightActionsProvider);
        final ControlTrail? proposal = actions.proposeTrail(insight);
        if (proposal == null) {
          _snack(context, 'Ainda não há histórico suficiente para montar uma trilha.');
          return;
        }
        final accepted = await showTrailProposalSheet(context, proposal);
        if (!accepted || !context.mounted) return;
        setState(() => _hidden.add(insight.id));
        await _guard(context, () => actions.acceptTrail(proposal), 'Trilha criada! Bora, formiguinha 🐜');
    }
  }

  Future<void> _confirmAbandon(BuildContext context, Future<void> Function() abandon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonar trilha?'),
        content: const Text('O progresso deixa de ser acompanhado. Você pode criar outra quando quiser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abandonar')),
        ],
      ),
    );
    if (ok == true && context.mounted) await _guard(context, abandon, 'Trilha abandonada');
  }

  static Future<void> _guard(BuildContext context, Future<void> Function() op, String? done) async {
    try {
      await op();
      if (done != null && context.mounted) _snack(context, done);
    } catch (e) {
      if (context.mounted) _snack(context, 'Não deu certo: $e');
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _PeriodCaption extends StatelessWidget {
  const _PeriodCaption(this.now);

  final DateTime now;

  static const _months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  static String _label(DateTime date) {
    final name = _months[date.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final current = DateTime(now.year, now.month);
    final previous = DateTime(now.year, now.month - 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Mês atual: ${_label(current)} · último mês fechado: ${_label(previous)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gray),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => FormetasCard(
        child: Column(
          children: [
            const Icon(Icons.emoji_nature_rounded, size: 40, color: AppColors.secondary),
            const SizedBox(height: 8),
            Text(
              'Tudo tranquilo no formigueiro',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quando algo fugir do padrão, a formiguinha avisa aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray),
            ),
          ],
        ),
      );
}
