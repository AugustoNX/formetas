import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/control_trail.dart';
import '../../../domain/services/ant_voice.dart';

/// Mostra a trilha proposta e devolve `true` se o usuário aceitar.
Future<bool> showTrailProposalSheet(BuildContext context, ControlTrail trail) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TrailProposalSheet(trail: trail),
  );
  return accepted ?? false;
}

class _TrailProposalSheet extends StatelessWidget {
  const _TrailProposalSheet({required this.trail});

  final ControlTrail trail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = trail.kind == TrailKind.category
        ? 'em ${trail.category}'
        : 'em compras de até ${AntVoice.money(trail.smallPurchaseLimit)}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trail.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Hoje você gasta ~${AntVoice.money(trail.weeklyBaseline)} por semana $scope. '
              'A formiguinha propõe reduzir aos poucos:',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.gray),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < trail.weeks; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 72, child: Text('Semana ${i + 1}')),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: trail.weeklyBaseline <= 0
                              ? 0
                              : (trail.weeklyTargets[i] / trail.weeklyBaseline).clamp(0.0, 1.0),
                          minHeight: 8,
                          color: AppColors.secondary,
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'até ${AntVoice.money(trail.weeklyTargets[i])}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Economia estimada: ${AntVoice.money(trail.plannedSaving)} em ${trail.weeks} semanas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Agora não'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Aceitar trilha'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
