import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/anthill_snapshot.dart';

/// Paleta natural do Formigueiro.
///
/// No tema claro o ambiente é um jardim ao meio-dia; no escuro, o mesmo
/// formigueiro observado à noite, iluminado por dentro.
class AnthillPalette {
  const AnthillPalette({
    required this.isDark,
    required this.skyTop,
    required this.skyBottom,
    required this.soil,
    required this.soilShade,
    required this.soilDeep,
    required this.tunnel,
    required this.leaf,
    required this.leafLight,
    required this.leafDark,
    required this.grass,
    required this.antBody,
    required this.antShade,
    required this.glow,
    required this.outline,
  });

  factory AnthillPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const AnthillPalette(
        isDark: true,
        skyTop: Color(0xFF101A14),
        skyBottom: Color(0xFF1C261C),
        soil: Color(0xFF3A2E22),
        soilShade: Color(0xFF2B211A),
        soilDeep: Color(0xFF201913),
        tunnel: Color(0xFF15100C),
        leaf: Color(0xFF6FA85A),
        leafLight: Color(0xFF9BCB7E),
        leafDark: Color(0xFF3F6B36),
        grass: Color(0xFF4C7A3C),
        antBody: Color(0xFF8B5E3C),
        antShade: Color(0xFF5F3F27),
        glow: Color(0xFFE7B84B),
        outline: Color(0xFF120E0A),
      );
    }

    return const AnthillPalette(
      isDark: false,
      skyTop: Color(0xFFEFF6E4),
      skyBottom: Color(0xFFDCEBC9),
      soil: Color(0xFF9C7248),
      soilShade: Color(0xFF7D5A38),
      soilDeep: Color(0xFF6A4B2F),
      tunnel: Color(0xFF54371F),
      leaf: Color(0xFF4F7942),
      leafLight: Color(0xFF7FB069),
      leafDark: Color(0xFF35552C),
      grass: Color(0xFF5C8A3E),
      antBody: Color(0xFF7A4E2E),
      antShade: Color(0xFF5A3720),
      glow: Color(0xFFD4A017),
      outline: Color(0xFF3B2716),
    );
  }

  final bool isDark;
  final Color skyTop;
  final Color skyBottom;
  final Color soil;
  final Color soilShade;
  final Color soilDeep;
  final Color tunnel;
  final Color leaf;
  final Color leafLight;
  final Color leafDark;
  final Color grass;
  final Color antBody;
  final Color antShade;
  final Color glow;
  final Color outline;

  Color get surface => isDark ? AppColors.darkCard : AppColors.white;

  Color get muted => AppColors.gray;

  /// Fundo das salas. Um tom de folha bem suave, o suficiente para o
  /// Formigueiro parecer outro ambiente sem brigar com o tema do aplicativo.
  Color get roomBackground =>
      isDark ? const Color(0xFF131A13) : const Color(0xFFF3F7EA);
}

abstract final class AntIcons {
  static IconData of(AntIcon icon) => switch (icon) {
        AntIcon.leaf => Icons.eco_rounded,
        AntIcon.ant => Icons.bug_report_rounded,
        AntIcon.anthill => Icons.terrain_rounded,
        AntIcon.storage => Icons.inventory_2_rounded,
        AntIcon.invest => Icons.trending_up_rounded,
        AntIcon.trophy => Icons.emoji_events_rounded,
        AntIcon.snowflake => Icons.ac_unit_rounded,
        AntIcon.target => Icons.flag_rounded,
        AntIcon.streak => Icons.local_fire_department_rounded,
        AntIcon.star => Icons.auto_awesome_rounded,
        AntIcon.harvest => Icons.spa_rounded,
        AntIcon.sprout => Icons.grass_rounded,
      };
}
