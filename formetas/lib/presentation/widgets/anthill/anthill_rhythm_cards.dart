import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../../domain/entities/category_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/anthill_providers.dart';
import '../../providers/data_providers.dart';
import '../formetas_card.dart';
import 'anthill_palette.dart';
import 'anthill_widgets.dart';

class AntSpeech extends StatelessWidget {
  const AntSpeech({super.key, required this.text, this.animated = true});

  final String text;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.leaf.withValues(alpha: palette.isDark ? 0.16 : 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
    );

    if (!animated) return bubble;
    return bubble
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.12, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

class WeeklyChallengeCard extends StatelessWidget {
  const WeeklyChallengeCard({
    super.key,
    required this.challenge,
    required this.trailSteps,
    this.animated = true,
  });

  final WeeklyChallenge challenge;
  final int trailSteps;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final done = challenge.isComplete;
    final stopped = challenge.stopped;
    final color = done
        ? palette.leaf
        : stopped
            ? AppColors.accent
            : palette.glow;

    final card = FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.directions_walk_rounded
                    : stopped
                        ? Icons.pause_rounded
                        : AntIcons.of(challenge.icon),
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  challenge.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: challenge.progress),
            duration: animated
                ? const Duration(milliseconds: 650)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => AnthillProgressBar(
              value: value,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge.progressLabel,
            style: TextStyle(
              color: palette.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge.detail,
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.35),
          ),
          if (done) ...[
            const SizedBox(height: 10),
            Text(
              trailSteps == 1
                  ? '1 passo na trilha do inverno'
                  : '$trailSteps passos na trilha do inverno',
              style: TextStyle(
                color: palette.leaf,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );

    if (!animated || !done) return card;
    return card
        .animate()
        .fadeIn(duration: 280.ms)
        .scale(begin: const Offset(0.98, 0.98), duration: 280.ms);
  }
}

class SpendingTrailCard extends StatelessWidget {
  const SpendingTrailCard({
    super.key,
    required this.trail,
    this.animated = true,
  });

  final SpendingTrail trail;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Trilha de 7 dias',
            subtitle: 'Um limite curto, numa categoria que você escolhe.',
          ),
          if (!trail.active)
            const Text(
              'Escolha uma categoria e dê um passo por dia sem gastar nela. '
              'No sétimo, a formiga chega ao armazém.',
              style: TextStyle(fontSize: 13, height: 1.35),
            )
          else ...[
            Text(
              trail.category!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < trail.days.length; i++)
                  Expanded(
                    child: _TrailStone(
                      day: trail.days[i],
                      index: i,
                      animated: animated,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _status(trail),
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 14),
          _TrailAction(trail: trail),
        ],
      ),
    );
  }

  String _status(SpendingTrail trail) {
    if (trail.arrived) {
      return 'A formiga chegou ao armazém. Sete dias sem ${trail.category}.';
    }
    if (trail.finished) {
      return 'A trilha fechou com ${trail.steps} passos. Dá para começar de novo.';
    }
    final today = trail.days.indexWhere((day) => day == null);
    final index = today == -1 ? trail.days.length : today;
    return 'Dia $index de 7 · ${trail.steps} passos';
  }
}

class _TrailStone extends StatelessWidget {
  const _TrailStone({
    required this.day,
    required this.index,
    required this.animated,
  });

  final bool? day;
  final int index;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final clean = day == true;
    final missed = day == false;
    final icon = Icon(
      missed
          ? Icons.close_rounded
          : clean
              ? Icons.circle
              : Icons.circle_outlined,
      size: 18,
      color: missed
          ? AppColors.accent
          : clean
              ? palette.leaf
              : palette.muted.withValues(alpha: 0.4),
    );

    return Column(
      children: [
        clean && animated
            ? icon
                .animate(key: ValueKey('stone-$index'))
                .scale(
                  begin: const Offset(0.4, 0.4),
                  duration: 280.ms,
                  curve: Curves.easeOutBack,
                )
            : icon,
        const SizedBox(height: 4),
        Text(
          '${index + 1}',
          style: TextStyle(color: palette.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _TrailAction extends ConsumerWidget {
  const _TrailAction({required this.trail});

  final SpendingTrail trail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrived = trail.arrived;
    final label = !trail.active
        ? 'Começar trilha de 7 dias'
        : arrived
            ? 'Nova trilha'
            : trail.finished
                ? 'Tentar de novo'
                : 'Trocar categoria';

    if (arrived) {
      return FilledButton.icon(
        onPressed: () => _pick(context, ref),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _pick(context, ref),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: Text(label),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final names = _expenseNames(ref);
    if (!context.mounted) return;

    if (names.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Text(
            'Registre uma despesa para escolher a categoria da trilha.',
            style: TextStyle(height: 1.35),
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Sem gasto nesta categoria',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            for (final name in names)
              ListTile(
                title: Text(name),
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(anthillTrailControllerProvider).start(selected);
  }

  List<String> _expenseNames(WidgetRef ref) {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const <CategoryEntity>[];
    final transactions =
        ref.read(transactionsProvider).valueOrNull ?? const <TransactionEntity>[];
    final names = <String>{};
    for (final category in categories) {
      if (category.type == TransactionType.expense && category.name.trim().isNotEmpty) {
        names.add(category.name.trim());
      }
    }
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      final name = transaction.category.trim();
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }
}
