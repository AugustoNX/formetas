import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/control_trail.dart';
import '../../../domain/services/ant_voice.dart';
import '../formetas_card.dart';

/// Trilha em andamento: semana atual, metas semanais e ações.
class ControlTrailCard extends StatelessWidget {
  const ControlTrailCard({
    super.key,
    required this.progress,
    required this.now,
    required this.onAbandon,
    required this.onComplete,
  });

  final TrailProgress progress;
  final DateTime now;
  final VoidCallback onAbandon;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trail = progress.trail;
    final current = progress.currentWeek;
    final over = current != null && current.spent > current.target;
    final barColor = over ? AppColors.expense : AppColors.secondary;

    return FormetasCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trail.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray),
                onSelected: (v) => v == 'abandon' ? onAbandon() : onComplete(),
                itemBuilder: (_) => [
                  if (progress.isFinished)
                    const PopupMenuItem(value: 'complete', child: Text('Concluir trilha')),
                  const PopupMenuItem(value: 'abandon', child: Text('Abandonar trilha')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (current != null) ...[
            Text(
              'Semana ${current.index + 1} de ${trail.weeks}: '
              '${AntVoice.money(current.spent)} de ${AntVoice.money(current.target)}',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: current.ratio.clamp(0.0, 1.0),
                minHeight: 10,
                color: barColor,
                backgroundColor: barColor.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              over
                  ? 'Passou ${AntVoice.money(-current.remaining)} da meta desta semana.'
                  : 'Ainda cabem ${AntVoice.money(current.remaining)} nesta semana.',
              style: theme.textTheme.bodySmall?.copyWith(color: over ? AppColors.expense : AppColors.gray),
            ),
          ] else if (progress.isFinished)
            Text(
              'Trilha encerrada: ${progress.metCount} de ${trail.weeks} semanas na meta.',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final week in progress.weeks)
                Expanded(child: _WeekChip(week: week)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Antes: ~${AntVoice.money(trail.weeklyBaseline)}/semana · '
                  'meta de economia ${AntVoice.money(trail.plannedSaving)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.gray),
                ),
              ),
              if (progress.isFinished)
                FilledButton(onPressed: onComplete, child: const Text('Concluir')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.week});

  final TrailWeek week;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (week.status) {
      TrailWeekStatus.met => (AppColors.income, Icons.check_circle_rounded),
      TrailWeekStatus.missed => (AppColors.expense, Icons.cancel_rounded),
      TrailWeekStatus.inProgress => (AppColors.accent, Icons.timelapse_rounded),
      TrailWeekStatus.upcoming => (AppColors.gray, Icons.radio_button_unchecked_rounded),
    };
    return Tooltip(
      message: 'Gasto ${AntVoice.money(week.spent)}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text('S${week.index + 1}', style: const TextStyle(fontSize: 11, color: AppColors.gray)),
            Text(
              AntVoice.money(week.target),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
