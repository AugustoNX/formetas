import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/anthill_catalog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/leaf_formatter.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../providers/anthill_providers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/anthill/ant_character.dart';
import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_widgets.dart';
import '../../widgets/formetas_card.dart';

/// "Sua formiga": nome, nível, energia, evolução e preferências da experiência.
class AntCareScreen extends ConsumerWidget {
  const AntCareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(anthillSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sua formiga')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Não conseguimos carregar sua formiga agora.'),
        ),
        data: (data) => _Content(snapshot: data),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.snapshot});

  final AnthillSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AnthillPalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormetasCard(
                child: Column(
                  children: [
                    AntCharacter(
                      level: snapshot.level.level,
                      size: 170,
                      animated: snapshot.profile.animationsEnabled,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            snapshot.profile.antName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dar um nome à sua formiga',
                          onPressed: () => _renameAnt(context, ref),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                    Text(
                      '${snapshot.level.title} · Nível ${snapshot.level.level}',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.level.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnthillProgressBar(value: snapshot.levelProgress, height: 12),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.nextLevel == null
                          ? 'Sua formiga alcançou o topo da jornada.'
                          : 'Faltam ${CurrencyFormatter.format(snapshot.remainingToNextLevel)} '
                              'para ${snapshot.nextLevel!.title}',
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FormetasCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AnthillSectionHeader(
                      title: 'Como está sua formiga',
                      subtitle: 'Um retrato do que você já construiu.',
                    ),
                    LeafCounter(amount: snapshot.netWorth, compact: true),
                    const SizedBox(height: 18),
                    Text(
                      'Energia',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AntEnergyBar(energy: snapshot.energy),
                    const SizedBox(height: 8),
                    Text(
                      'A energia acompanha sua consistência. Ela nunca bloqueia '
                      'nada no aplicativo.',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Conquistas',
                            value:
                                '${snapshot.unlockedCount}/${snapshot.achievementCount}',
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Meses guardando',
                            value: '${snapshot.facts.monthsWithSavings}',
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Armazéns',
                            value: '${snapshot.facts.reserveCount}',
                          ),
                        ),
                      ],
                    ),
                    if (snapshot.profile.createdAt != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Cuidando do formigueiro desde '
                        '${AppDateUtils.formatDate(snapshot.profile.createdAt!)}',
                        style: TextStyle(color: palette.muted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FormetasCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AnthillSectionHeader(
                      title: 'Jornada da formiga',
                      subtitle: 'Cada nível é uma etapa visual da sua evolução.',
                    ),
                    for (final level in AnthillCatalog.levels)
                      _LevelRow(
                        level: level,
                        current: level.level == snapshot.level.level,
                        reached: snapshot.level.level >= level.level,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FormetasCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AnthillSectionHeader(
                      title: 'Preferências',
                      subtitle: 'A experiência se adapta ao seu gosto.',
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: snapshot.profile.animationsEnabled,
                        onChanged: (value) => _setAnimations(ref, value),
                        title: const Text('Animações do formigueiro'),
                        subtitle: Text(
                          'Formigas caminhando, folhinhas caindo e comemorações.',
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/formigueiro/conquistas'),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Ver todas as conquistas'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setAnimations(WidgetRef ref, bool value) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref
        .read(anthillRepositoryProvider)
        .updateAnimationsEnabled(user.id, value);
  }

  Future<void> _renameAnt(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: snapshot.profile.antName);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome da sua formiga'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Como ela se chama?'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(anthillRepositoryProvider).updateAntName(user.id, trimmed);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: palette.muted, fontSize: 11.5)),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.current,
    required this.reached,
  });

  final AntLevel level;
  final bool current;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final color = reached ? palette.leaf : palette.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: reached ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(11),
              border: current
                  ? Border.all(color: palette.glow, width: 1.6)
                  : null,
            ),
            alignment: Alignment.center,
            child: reached
                ? Text(
                    '${level.level}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : Icon(Icons.lock_outline_rounded, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        level.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: current ? palette.leaf : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.glow.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'atual',
                          style: TextStyle(
                            color: palette.glow,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'A partir de ${LeafFormatter.label(level.threshold)}'
                  ' · ${CurrencyFormatter.format(level.threshold)}',
                  style: TextStyle(color: AppColors.gray, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
