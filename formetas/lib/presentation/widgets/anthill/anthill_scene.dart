import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'anthill_palette.dart';

/// O formigueiro que cresce junto com o patrimônio.
///
/// Cada nível abre uma nova sala subterrânea; o progresso dentro do nível
/// enche a sala atual de folhinhas. As salas ainda bloqueadas aparecem
/// esmaecidas, para dar a sensação de que sempre há algo a construir.
class AnthillScene extends StatefulWidget {
  const AnthillScene({
    super.key,
    required this.level,
    required this.levelProgress,
    required this.storageCount,
    this.height = 240,
    this.animated = true,
  });

  final int level;
  final double levelProgress;
  final int storageCount;
  final double height;
  final bool animated;

  @override
  State<AnthillScene> createState() => _AnthillSceneState();
}

class _AnthillSceneState extends State<AnthillScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnthillScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.25;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _AnthillPainter(
              level: widget.level,
              levelProgress: widget.levelProgress,
              storageCount: widget.storageCount,
              palette: palette,
              phase: _controller.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chamber {
  const _Chamber(this.x, this.y, this.radius);
  final double x;
  final double y;
  final double radius;
}

class _AnthillPainter extends CustomPainter {
  _AnthillPainter({
    required this.level,
    required this.levelProgress,
    required this.storageCount,
    required this.palette,
    required this.phase,
  });

  /// Posições relativas das salas, da primeira à última desbloqueada.
  static const _chambers = [
    _Chamber(0.50, 0.72, 0.085),
    _Chamber(0.28, 0.82, 0.072),
    _Chamber(0.73, 0.84, 0.072),
    _Chamber(0.16, 0.67, 0.058),
    _Chamber(0.86, 0.69, 0.058),
  ];

  final int level;
  final double levelProgress;
  final int storageCount;
  final AnthillPalette palette;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.5;
    final random = math.Random(level * 31 + storageCount);

    _paintSky(canvas, size);
    _paintHorizon(canvas, size, groundY);
    _paintSoil(canvas, size, groundY);

    final entrance = _paintMound(canvas, size, groundY);

    _paintTunnels(canvas, size, entrance);
    _paintChambers(canvas, size);
    _paintGrass(canvas, size, groundY, random);
    _paintSurfaceAnts(canvas, size, groundY, entrance);
  }

  // ---------------------------------------------------------------------------

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(rect),
    );

    if (palette.isDark) {
      final stars = math.Random(7);
      for (var i = 0; i < 26; i++) {
        final dx = stars.nextDouble() * size.width;
        final dy = stars.nextDouble() * size.height * 0.42;
        final twinkle =
            0.35 + 0.35 * math.sin((phase * 2 * math.pi) + i.toDouble());
        canvas.drawCircle(
          Offset(dx, dy),
          stars.nextDouble() * 1.1 + 0.5,
          Paint()..color = Colors.white.withValues(alpha: twinkle * 0.6),
        );
      }
      // Vaga-lumes acompanham o formigueiro à noite.
      for (var i = 0; i < 3 + level; i++) {
        final t = (phase + i * 0.17) % 1;
        final dx = size.width * (0.1 + 0.8 * ((i * 0.23 + t) % 1));
        final dy = size.height * (0.18 + 0.2 * math.sin(t * 2 * math.pi + i));
        canvas.drawCircle(
          Offset(dx, dy),
          2.4,
          Paint()
            ..color = palette.glow.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    } else {
      canvas.drawCircle(
        Offset(size.width * 0.86, size.height * 0.16),
        22,
        Paint()..color = palette.glow.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        Offset(size.width * 0.86, size.height * 0.16),
        13,
        Paint()..color = palette.glow.withValues(alpha: 0.75),
      );
    }
  }

  void _paintHorizon(Canvas canvas, Size size, double groundY) {
    final hills = Path()
      ..moveTo(0, groundY)
      ..quadraticBezierTo(
        size.width * 0.18,
        groundY - size.height * 0.16,
        size.width * 0.4,
        groundY,
      )
      ..lineTo(0, groundY)
      ..close();

    final farHills = Path()
      ..moveTo(size.width * 0.55, groundY)
      ..quadraticBezierTo(
        size.width * 0.78,
        groundY - size.height * 0.2,
        size.width,
        groundY,
      )
      ..lineTo(size.width * 0.55, groundY)
      ..close();

    final paint = Paint()..color = palette.grass.withValues(alpha: 0.28);
    canvas.drawPath(hills, paint);
    canvas.drawPath(farHills, paint);
  }

  void _paintSoil(Canvas canvas, Size size, double groundY) {
    final soilRect = Rect.fromLTRB(0, groundY, size.width, size.height);
    canvas.drawRect(
      soilRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.soil, palette.soilDeep],
        ).createShader(soilRect),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, 5),
      Paint()..color = palette.grass,
    );

    final speckle = math.Random(19);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(
          speckle.nextDouble() * size.width,
          groundY + speckle.nextDouble() * (size.height - groundY),
        ),
        speckle.nextDouble() * 1.4 + 0.4,
        Paint()..color = palette.soilShade.withValues(alpha: 0.5),
      );
    }
  }

  Offset _paintMound(Canvas canvas, Size size, double groundY) {
    final center = size.width * 0.5;
    final width = size.width * (0.28 + 0.045 * level.clamp(1, 5));
    final height = size.height * (0.13 + 0.035 * level.clamp(1, 5));

    final mound = Path()
      ..moveTo(center - width / 2, groundY)
      ..quadraticBezierTo(center - width * 0.34, groundY - height, center, groundY - height)
      ..quadraticBezierTo(center + width * 0.34, groundY - height, center + width / 2, groundY)
      ..close();

    canvas.drawPath(mound, Paint()..color = palette.soil);
    canvas.drawPath(
      Path()
        ..moveTo(center - width / 2, groundY)
        ..quadraticBezierTo(
          center - width * 0.3,
          groundY - height * 0.9,
          center - width * 0.05,
          groundY - height * 0.95,
        )
        ..lineTo(center - width * 0.05, groundY)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    final entrance = Offset(center, groundY - height * 0.72);
    canvas.drawOval(
      Rect.fromCenter(center: entrance, width: width * 0.22, height: height * 0.3),
      Paint()..color = palette.tunnel,
    );

    if (palette.isDark) {
      canvas.drawCircle(
        entrance,
        width * 0.16,
        Paint()
          ..color = palette.glow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    return entrance;
  }

  void _paintTunnels(Canvas canvas, Size size, Offset entrance) {
    final paint = Paint()
      ..color = palette.tunnel.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.016
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _chambers.length; i++) {
      final unlocked = i < level;
      final chamber = _chambers[i];
      final target = Offset(size.width * chamber.x, size.height * chamber.y);
      final control = Offset(
        (entrance.dx + target.dx) / 2 + (target.dx - entrance.dx) * 0.25,
        (entrance.dy + target.dy) / 2,
      );

      canvas.drawPath(
        Path()
          ..moveTo(entrance.dx, entrance.dy)
          ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy),
        Paint()
          ..color = paint.color.withValues(alpha: unlocked ? 0.85 : 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = paint.strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintChambers(Canvas canvas, Size size) {
    for (var i = 0; i < _chambers.length; i++) {
      final chamber = _chambers[i];
      final center = Offset(size.width * chamber.x, size.height * chamber.y);
      final radius = size.width * chamber.radius;
      final unlocked = i < level;

      if (!unlocked) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = palette.tunnel.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        continue;
      }

      canvas.drawCircle(center, radius, Paint()..color = palette.tunnel);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = palette.soilShade
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      if (palette.isDark) {
        canvas.drawCircle(
          center,
          radius * 1.25,
          Paint()
            ..color = palette.glow.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      final isCurrent = i == level - 1;
      final fill = isCurrent ? levelProgress.clamp(0.12, 1).toDouble() : 1.0;
      _paintLeafPile(canvas, center, radius, fill, seed: i);
    }
  }

  void _paintLeafPile(
    Canvas canvas,
    Offset center,
    double radius,
    double fill, {
    required int seed,
  }) {
    final random = math.Random(seed * 97 + 3);
    final count = (fill * 9).round().clamp(1, 9);

    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = random.nextDouble() * radius * 0.55;
      final position = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + radius * 0.35 - random.nextDouble() * radius * 0.7 * fill,
      );

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(random.nextDouble() * math.pi);
      final leafWidth = radius * 0.62;
      final path = Path()
        ..moveTo(-leafWidth / 2, 0)
        ..quadraticBezierTo(0, -leafWidth * 0.32, leafWidth / 2, 0)
        ..quadraticBezierTo(0, leafWidth * 0.32, -leafWidth / 2, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = i.isEven ? palette.leaf : palette.leafLight,
      );
      canvas.restore();
    }
  }

  void _paintGrass(Canvas canvas, Size size, double groundY, math.Random random) {
    final tufts = 5 + level * 2;
    final sway = math.sin(phase * 2 * math.pi) * 2;

    for (var i = 0; i < tufts; i++) {
      final x = random.nextDouble() * size.width;
      if ((x - size.width * 0.5).abs() < size.width * 0.16) continue;

      final height = 6 + random.nextDouble() * 10;
      final paint = Paint()
        ..color = palette.grass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      for (var blade = -1; blade <= 1; blade++) {
        canvas.drawPath(
          Path()
            ..moveTo(x + blade * 3, groundY + 2)
            ..quadraticBezierTo(
              x + blade * 4 + sway,
              groundY - height * 0.6,
              x + blade * 5 + sway * 1.4,
              groundY - height,
            ),
          paint,
        );
      }
    }
  }

  void _paintSurfaceAnts(
    Canvas canvas,
    Size size,
    double groundY,
    Offset entrance,
  ) {
    final antCount = level >= 5 ? 3 : (level >= 3 ? 2 : 1);

    for (var i = 0; i < antCount; i++) {
      final t = (phase + i * 0.33) % 1;
      final fromLeft = i.isEven;
      final startX = fromLeft ? -20.0 : size.width + 20;
      final x = startX + (entrance.dx - startX) * Curves.easeInOut.transform(t);
      final bob = math.sin(t * 30) * 1.2;

      _drawMiniAnt(
        canvas,
        Offset(x, groundY - 4 + bob),
        size.width * 0.028,
        facingRight: fromLeft,
        carrying: t < 0.85,
      );
    }
  }

  void _drawMiniAnt(
    Canvas canvas,
    Offset position,
    double scale, {
    required bool facingRight,
    required bool carrying,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (!facingRight) canvas.scale(-1, 1);

    final body = Paint()..color = palette.antBody;
    final legs = Paint()
      ..color = palette.antShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.22
      ..strokeCap = StrokeCap.round;

    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(i * scale * 0.5, scale * 0.2),
        Offset(i * scale * 0.5 + scale * 0.3, scale * 0.9),
        legs,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-scale * 0.85, 0),
        width: scale * 1.2,
        height: scale * 0.95,
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: scale * 0.9, height: scale * 0.8),
      body,
    );
    canvas.drawCircle(Offset(scale * 0.75, -scale * 0.1), scale * 0.45, body);

    if (carrying) {
      canvas.save();
      canvas.translate(0, -scale * 0.95);
      canvas.rotate(-0.2);
      final width = scale * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(-width / 2, 0)
          ..quadraticBezierTo(0, -width * 0.3, width / 2, 0)
          ..quadraticBezierTo(0, width * 0.3, -width / 2, 0)
          ..close(),
        Paint()..color = palette.leafLight,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnthillPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.levelProgress != levelProgress ||
        oldDelegate.storageCount != storageCount ||
        oldDelegate.phase != phase ||
        oldDelegate.palette.isDark != palette.isDark;
  }
}
