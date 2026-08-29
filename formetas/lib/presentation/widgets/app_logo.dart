import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';

/// Marca do Formetas. A logo já traz o fundo verde, então só recortamos
/// os cantos — sem pintar outro quadrado por cima.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.radius,
    this.showShadow = false,
  });

  final double size;
  final double? radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius ?? size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: size * 0.24,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AppAssets.logo,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Formiga isolada, para usar em fundos claros sem o quadrado verde.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logoTransparent,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}
