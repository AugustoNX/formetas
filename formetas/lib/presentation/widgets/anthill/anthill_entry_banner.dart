import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/leaf_formatter.dart';
import '../../providers/anthill_providers.dart';
import '../../providers/app_mode_provider.dart';
import 'ant_character.dart';
import 'anthill_palette.dart';

/// Porta de entrada do Formigueiro dentro do Formetas financeiro.
///
/// Tocar aqui troca a experiência inteira — navegação e telas —, não abre
/// apenas mais uma aba.
class AnthillEntryBanner extends ConsumerWidget {
  const AnthillEntryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AnthillPalette.of(context);
    final snapshot = ref.watch(anthillSnapshotProvider).valueOrNull;

    Future<void> enter() async {
      await ref.read(appModeProvider.notifier).enterAnthill();
      if (context.mounted) context.go('/formigueiro');
    }

    final subtitle = snapshot == null
        ? 'Veja seu dinheiro como o formigueiro que você está construindo.'
        : '${snapshot.level.title} · '
            '${LeafFormatter.label(snapshot.netWorth)} guardadas';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enter,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                palette.leaf.withValues(alpha: palette.isDark ? 0.24 : 0.16),
                palette.leafLight.withValues(alpha: palette.isDark ? 0.1 : 0.08),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: palette.leaf.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              AntCharacter(
                level: snapshot?.level.level ?? 1,
                size: 58,
                animated: snapshot?.profile.animationsEnabled ?? false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrar no formigueiro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: palette.leaf, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
