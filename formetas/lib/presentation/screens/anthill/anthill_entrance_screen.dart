import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../widgets/anthill/ant_character.dart';
import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_scene.dart';
import '../../widgets/anthill/anthill_sections.dart';
import '../../widgets/anthill/anthill_widgets.dart';

/// A entrada do formigueiro: onde a formiga aparece, o inverno é anunciado e
/// dá para descer para as outras salas.
class AnthillEntranceScreen extends StatelessWidget {
  const AnthillEntranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.terrain_rounded,
      title: 'Entrada',
      subtitle: 'O inverno está chegando. Cada folhinha guardada hoje conta.',
      body: (context, snapshot) => [
        _Headline(text: snapshot.headline),
        const SizedBox(height: 16),
        AnthillScene(
          level: snapshot.level.level,
          levelProgress: snapshot.levelProgress,
          storageCount: snapshot.facts.reserveCount,
          animated: snapshot.profile.animationsEnabled,
        ),
        const SizedBox(height: 16),
        AntSummaryCard(snapshot: snapshot),
        const SizedBox(height: 16),
      ],
      aside: (context, snapshot) => [
        WinterCard(
          winter: snapshot.winter,
          onTap: () => _showWinterDetails(context, snapshot.winter),
        ),
        const SizedBox(height: 16),
        WinterChecklistCard(winter: snapshot.winter),
        const SizedBox(height: 16),
        if (snapshot.nextAchievement case final next?) ...[
          NextAchievementCard(achievement: next),
          const SizedBox(height: 16),
        ],
        const _EntranceActions(),
      ],
    );
  }

  void _showWinterDetails(BuildContext context, WinterStatus winter) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Preparação para o inverno',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'O inverno é o futuro. Cada folhinha guardada hoje deixa sua '
                'formiga mais tranquila depois.',
                style: TextStyle(color: AppColors.gray, height: 1.4),
              ),
              const SizedBox(height: 20),
              for (final task in winter.tasks) WinterTaskTile(task: task),
              const SizedBox(height: 12),
              Text(
                winter.message,
                style: TextStyle(color: AppColors.gray, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.leaf.withValues(alpha: palette.isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const LeafGlyph(size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntranceActions extends StatelessWidget {
  const _EntranceActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/formigueiro/formiga'),
          icon: const Icon(Icons.pets_rounded, size: 18),
          label: const Text('Cuidar da sua formiga'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        const LeaveAnthillButton(),
      ],
    );
  }
}
