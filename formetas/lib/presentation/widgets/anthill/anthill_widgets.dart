import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/leaf_formatter.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import 'ant_character.dart';
import 'anthill_palette.dart';

/// Barra de progresso com acabamento orgânico, usada em níveis, missões,
/// conquistas e na preparação para o inverno.
class AnthillProgressBar extends StatelessWidget {
  const AnthillProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.background,
    this.animate = true,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? background;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final fill = color ?? palette.leaf;
    final track = background ?? palette.muted.withValues(alpha: 0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: track),
            LayoutBuilder(
              builder: (context, constraints) {
                final decoration = BoxDecoration(
                  gradient: LinearGradient(colors: [fill, palette.leafLight]),
                  borderRadius: BorderRadius.circular(height),
                );
                final width = constraints.maxWidth * value.clamp(0, 1);

                return AnimatedContainer(
                  duration: animate
                      ? const Duration(milliseconds: 650)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  width: width,
                  decoration: decoration,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Contador de folhinhas com o valor real em reais logo abaixo.
class LeafCounter extends StatelessWidget {
  const LeafCounter({
    super.key,
    required this.amount,
    this.label = 'Folhinhas coletadas',
    this.alignment = CrossAxisAlignment.start,
    this.compact = false,
  });

  final double amount;
  final String label;
  final CrossAxisAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LeafGlyph(size: compact ? 18 : 24),
              const SizedBox(width: 8),
              Text(
                LeafFormatter.count(amount),
                style: TextStyle(
                  fontSize: compact ? 22 : 30,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              color: palette.muted,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Energia da formiga: leitura da consistência, nunca um bloqueio.
class AntEnergyBar extends StatelessWidget {
  const AntEnergyBar({super.key, required this.energy, this.showMessage = true});

  final AntEnergy energy;
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < AntEnergy.maxLevel; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: i < energy.level
                      ? palette.glow
                      : palette.muted.withValues(alpha: 0.28),
                ),
              ),
          ],
        ),
        if (showMessage) ...[
          const SizedBox(height: 6),
          Text(
            energy.message,
            style: TextStyle(color: palette.muted, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

class WinterCard extends StatelessWidget {
  const WinterCard({super.key, required this.winter, this.onTap});

  final WinterStatus winter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final accent = palette.isDark
        ? const Color(0xFF8FC8E8)
        : const Color(0xFF4E7E9B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: palette.isDark ? 0.12 : 0.09),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.ac_unit_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      winter.headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    'em ${winter.daysRemaining} dias',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${winter.readinessPercent}%',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'preparado',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnthillProgressBar(value: winter.readiness, color: accent),
              const SizedBox(height: 12),
              Text(
                winter.message,
                style: TextStyle(color: palette.muted, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WinterTaskTile extends StatelessWidget {
  const WinterTaskTile({super.key, required this.task});

  final WinterTask task;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final done = task.isDone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: done ? palette.leaf : palette.muted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: done ? palette.leaf : null,
                  ),
                ),
                const SizedBox(height: 6),
                AnthillProgressBar(value: task.progress, height: 6),
                const SizedBox(height: 5),
                Text(
                  _progressLabel(task),
                  style: TextStyle(color: palette.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _progressLabel(WinterTask task) {
    if (task.unit == AnthillUnit.currency) {
      return '${CurrencyFormatter.format(task.current)} de '
          '${CurrencyFormatter.format(task.target)}';
    }
    return '${task.current.round()} de ${task.target.round()}';
  }
}

class MissionTile extends StatelessWidget {
  const MissionTile({super.key, required this.mission});

  final MissionStatus mission;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final done = mission.isComplete;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? palette.leaf.withValues(alpha: 0.45)
              : palette.muted.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (done ? palette.leaf : palette.glow).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : AntIcons.of(mission.definition.icon),
              size: 20,
              color: done ? palette.leaf : palette.glow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.definition.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  done
                      ? 'Missão concluída. Sua formiga agradece.'
                      : mission.definition.description,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                AnthillProgressBar(
                  value: mission.progress,
                  height: 7,
                  color: done ? palette.leaf : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _label(mission),
                  style: TextStyle(color: palette.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(MissionStatus mission) {
    if (mission.isComplete) return 'Concluída';
    if (mission.definition.unit == AnthillUnit.currency) {
      return 'Faltam ${CurrencyFormatter.format(mission.remaining)}';
    }
    return '${mission.current.round()} de ${mission.target.round()}';
  }
}

class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement});

  final AchievementStatus achievement;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final unlocked = achievement.isUnlocked;
    final accent = unlocked ? palette.glow : palette.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? palette.glow.withValues(alpha: 0.4)
              : palette.muted.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: unlocked ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  unlocked
                      ? AntIcons.of(achievement.definition.icon)
                      : Icons.lock_outline_rounded,
                  size: 19,
                  color: accent,
                ),
              ),
              const Spacer(),
              if (unlocked)
                Icon(Icons.verified_rounded, size: 18, color: palette.leaf),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            achievement.definition.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // O texto cede espaço primeiro: o cartão vive dentro de uma grade de
          // altura fixa e nunca deve estourar em telas estreitas.
          Flexible(
            child: Text(
              unlocked
                  ? achievement.definition.description
                  : achievement.definition.lockedHint,
              style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          AnthillProgressBar(
            value: achievement.progress,
            height: 6,
            color: unlocked ? palette.glow : null,
          ),
        ],
      ),
    );
  }
}

/// Grade de conquistas com altura fixa por cartão: o número de colunas se
/// adapta à largura, mas o conteúdo nunca é espremido.
class AchievementGrid extends StatelessWidget {
  const AchievementGrid({super.key, required this.achievements});

  static const _tileHeight = 186.0;

  final List<AchievementStatus> achievements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          >= 860 => 4,
          >= 620 => 3,
          _ => 2,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: achievements.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: _tileHeight,
          ),
          itemBuilder: (context, index) =>
              AchievementTile(achievement: achievements[index]),
        );
      },
    );
  }
}

/// Cabeçalho de seção com a mesma linguagem do restante do aplicativo.
class AnthillSectionHeader extends StatelessWidget {
  const AnthillSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Faixa com a leitura lúdica do mês: coletado, utilizado e guardado.
class LeafFlowRow extends StatelessWidget {
  const LeafFlowRow({super.key, required this.facts});

  final AnthillFacts facts;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    final items = [
      (
        label: 'Coletadas',
        value: facts.collectedThisMonth,
        color: AppColors.income,
        icon: Icons.south_west_rounded,
      ),
      (
        label: 'Utilizadas',
        value: facts.usedThisMonth,
        color: AppColors.accent,
        icon: Icons.north_east_rounded,
      ),
      (
        label: 'Guardadas',
        value: facts.savedThisMonth,
        color: palette.leaf,
        icon: Icons.inventory_2_outlined,
      ),
    ];

    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, size: 16, color: item.color),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(color: palette.muted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      LeafFormatter.count(item.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(item.value),
                    style: TextStyle(color: palette.muted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
