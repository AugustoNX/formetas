import 'package:flutter/material.dart';

import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_widgets.dart';

/// Sala das conquistas. As bloqueadas continuam visíveis de propósito: saber
/// o que vem a seguir é parte da motivação.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.emoji_events_rounded,
      title: 'Conquistas',
      subtitle: 'A memória do que sua formiga já construiu.',
      body: (context, snapshot) {
        final palette = AnthillPalette.of(context);
        final all = snapshot.achievements;
        final unlocked = all.where((a) => a.isUnlocked).toList();
        final locked = all.where((a) => !a.isUnlocked).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));

        return [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.glow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: palette.glow,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${unlocked.length} de ${all.length} desbloqueadas',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnthillProgressBar(
                        value: all.isEmpty ? 0 : unlocked.length / all.length,
                        color: palette.glow,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pequenas conquistas constroem grandes patrimônios.',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (unlocked.isNotEmpty) ...[
            const AnthillSectionHeader(title: 'Já conquistadas'),
            AchievementGrid(achievements: unlocked),
            const SizedBox(height: 28),
          ],
          if (locked.isNotEmpty) ...[
            const AnthillSectionHeader(
              title: 'A caminho',
              subtitle: 'O que sua formiga pode alcançar em seguida.',
            ),
            AchievementGrid(achievements: locked),
          ],
        ];
      },
    );
  }
}
