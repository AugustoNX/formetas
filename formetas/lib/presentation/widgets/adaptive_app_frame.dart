import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';

/// Centraliza o app em uma coluna no computador, sem alterar o layout no celular.
class AdaptiveAppFrame extends StatelessWidget {
  const AdaptiveAppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;

    if (screenWidth <= AppBreakpoints.contentMaxWidth) {
      return child;
    }

    final contentWidth = AppBreakpoints.contentMaxWidth;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sideColor =
        isDark ? const Color(0xFF121612) : const Color(0xFFE4E4C8);

    return ColoredBox(
      color: sideColor,
      child: Center(
        child: Container(
          width: contentWidth,
          height: media.size.height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                blurRadius: 32,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(
              size: Size(contentWidth, media.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
