import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/anthill_providers.dart';
import 'anthill_palette.dart';

/// Envolve o aplicativo para dois papéis discretos:
///
/// 1. sincronizar as conquistas alcançadas com o perfil salvo;
/// 2. mostrar uma comemoração curta quando algo novo acontece.
///
/// Nada aqui interfere em telas ou fluxos financeiros: é uma sobreposição.
class AnthillCelebrationHost extends ConsumerStatefulWidget {
  const AnthillCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnthillCelebrationHost> createState() =>
      _AnthillCelebrationHostState();
}

class _AnthillCelebrationHostState
    extends ConsumerState<AnthillCelebrationHost> {
  @override
  Widget build(BuildContext context) {
    ref.listen(anthillSnapshotProvider, (previous, next) {
      final snapshot = next.valueOrNull;
      if (snapshot == null) return;
      Future.microtask(
        () => ref.read(anthillSyncProvider.notifier).sync(snapshot),
      );
    });

    final queue = ref.watch(anthillSyncProvider);
    final animationsEnabled = ref
            .watch(antProfileProvider)
            .valueOrNull
            ?.animationsEnabled ??
        true;

    return Stack(
      children: [
        widget.child,
        if (queue.isNotEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: _CelebrationBanner(
                key: ValueKey(queue.first.message),
                celebration: queue.first,
                animated: animationsEnabled,
                onDismiss: () =>
                    ref.read(anthillSyncProvider.notifier).dismissCurrent(),
              ),
            ),
          ),
      ],
    );
  }
}

class _CelebrationBanner extends StatefulWidget {
  const _CelebrationBanner({
    super.key,
    required this.celebration,
    required this.animated,
    required this.onDismiss,
  });

  final AnthillCelebration celebration;
  final bool animated;
  final VoidCallback onDismiss;

  @override
  State<_CelebrationBanner> createState() => _CelebrationBannerState();
}

class _CelebrationBannerState extends State<_CelebrationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final entry = Curves.easeOutBack.transform((t / 0.12).clamp(0, 1));
        final exit = t > 0.9 ? (t - 0.9) / 0.1 : 0.0;

        return Opacity(
          opacity: (1 - exit).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -30 * (1 - entry) - 20 * exit),
            child: Transform.scale(scale: 0.94 + 0.06 * entry, child: child),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          if (widget.animated)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _LeafConfettiPainter(
                      progress: _controller.value,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onDismiss,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.glow.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.glow.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        AntIcons.of(widget.celebration.icon),
                        color: palette.glow,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.celebration.title,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.celebration.message,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folhinhas caindo atrás do aviso. Curto, leve e sem bloquear toques.
class _LeafConfettiPainter extends CustomPainter {
  _LeafConfettiPainter({required this.progress, required this.palette});

  final double progress;
  final AnthillPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress > 0.55) return;

    final random = math.Random(5);
    final t = (progress / 0.55).clamp(0.0, 1.0);

    for (var i = 0; i < 14; i++) {
      final startX = random.nextDouble() * size.width;
      final drift = math.sin(t * math.pi * 2 + i) * 14;
      final y = -12 + t * (size.height + 60) * (0.7 + random.nextDouble() * 0.5);
      final opacity = (1 - t) * 0.9;

      canvas.save();
      canvas.translate(startX + drift, y);
      canvas.rotate(t * 6 + i);
      final width = 10.0 + random.nextDouble() * 5;
      canvas.drawPath(
        Path()
          ..moveTo(-width / 2, 0)
          ..quadraticBezierTo(0, -width * 0.32, width / 2, 0)
          ..quadraticBezierTo(0, width * 0.32, -width / 2, 0)
          ..close(),
        Paint()
          ..color = (i.isEven ? palette.leaf : palette.leafLight)
              .withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeafConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
