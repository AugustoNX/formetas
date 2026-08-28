import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'anthill_palette.dart';

/// A formiga do usuário, desenhada em código.
///
/// Nada de assets: o personagem é vetorial, acompanha o tema e ganha
/// acessórios conforme o nível — a evolução é visual e motivacional, nunca uma
/// vantagem financeira.
class AntCharacter extends StatefulWidget {
  const AntCharacter({
    super.key,
    required this.level,
    this.size = 140,
    this.animated = true,
    this.carryingLeaf,
  });

  final int level;
  final double size;
  final bool animated;

  /// Por padrão a formiga carrega uma folhinha a partir do nível 2.
  final bool? carryingLeaf;

  @override
  State<AntCharacter> createState() => _AntCharacterState();
}

class _AntCharacterState extends State<AntCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AntCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
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

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: AntPainter(
              level: widget.level,
              palette: palette,
              phase: _controller.value,
              carryingLeaf: widget.carryingLeaf ?? widget.level >= 2,
            ),
          );
        },
      ),
    );
  }
}

class AntPainter extends CustomPainter {
  AntPainter({
    required this.level,
    required this.palette,
    required this.phase,
    required this.carryingLeaf,
  });

  /// O desenho é criado neste espaço e depois escalado para o tamanho pedido.
  static const _design = Size(100, 100);

  final int level;
  final AnthillPalette palette;
  final double phase;
  final bool carryingLeaf;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _design.width;
    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale);

    final wave = math.sin(phase * 2 * math.pi);
    canvas.translate(0, wave * 1.2);

    _paintGlow(canvas);
    _paintLegs(canvas, wave);
    if (carryingLeaf) _paintCarriedLeaf(canvas, wave);
    _paintBody(canvas);
    _paintAntennae(canvas, wave);
    _paintFace(canvas);
    _paintAccessories(canvas);

    canvas.restore();
  }

  void _paintGlow(Canvas canvas) {
    if (level < 5) return;
    canvas.drawCircle(
      const Offset(52, 52),
      44,
      Paint()
        ..color = palette.glow.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _paintLegs(Canvas canvas, double wave) {
    final paint = Paint()
      ..color = palette.antShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    final steps = [
      (from: const Offset(48, 60), to: const Offset(34, 80), lift: wave),
      (from: const Offset(58, 62), to: const Offset(56, 82), lift: -wave),
      (from: const Offset(66, 60), to: const Offset(78, 78), lift: wave),
    ];

    // Patas do lado oposto, mais claras e deslocadas, dão volume ao personagem.
    final farPaint = Paint()
      ..color = palette.antShade.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    for (final leg in steps) {
      final lift = leg.lift * 2.5;
      final path = Path()
        ..moveTo(leg.from.dx, leg.from.dy)
        ..quadraticBezierTo(
          (leg.from.dx + leg.to.dx) / 2 - 6,
          (leg.from.dy + leg.to.dy) / 2 + 4,
          leg.to.dx,
          leg.to.dy - lift,
        );

      canvas.save();
      canvas.translate(-7, -4);
      canvas.drawPath(path, farPaint);
      canvas.restore();

      canvas.drawPath(path, paint);
    }
  }

  void _paintBody(Canvas canvas) {
    final body = Paint()..color = palette.antBody;
    final shade = Paint()..color = palette.antShade;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(30, 52), width: 42, height: 34),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(24, 58), width: 28, height: 18),
      Paint()..color = palette.antShade.withValues(alpha: 0.35),
    );

    canvas.drawCircle(const Offset(51, 55), 5, shade);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 53), width: 24, height: 23),
      body,
    );

    canvas.drawCircle(const Offset(78, 46), 15, body);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(78, 46), radius: 15),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = palette.antShade.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Brilho suave, deixa o personagem mais fofo e menos "chapado".
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(26, 44), width: 16, height: 9),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  void _paintAntennae(Canvas canvas, double wave) {
    final paint = Paint()
      ..color = palette.antShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final sway = wave * 2.4;

    final left = Path()
      ..moveTo(72, 34)
      ..quadraticBezierTo(66, 22, 62 + sway, 14);
    final right = Path()
      ..moveTo(84, 34)
      ..quadraticBezierTo(90, 20, 88 + sway, 11);

    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);

    final tip = Paint()..color = palette.leafLight;
    canvas.drawCircle(Offset(62 + sway, 13), 2.6, tip);
    canvas.drawCircle(Offset(88 + sway, 10), 2.6, tip);
  }

  void _paintFace(Canvas canvas) {
    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = palette.outline;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(76, 44), width: 8, height: 9.5),
      eyeWhite,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(86, 44), width: 7, height: 8.5),
      eyeWhite,
    );
    canvas.drawCircle(const Offset(77, 45), 2.6, pupil);
    canvas.drawCircle(const Offset(87, 45), 2.3, pupil);
    canvas.drawCircle(const Offset(76, 43.6), 0.9, eyeWhite);
    canvas.drawCircle(const Offset(86.2, 43.6), 0.8, eyeWhite);

    canvas.drawArc(
      Rect.fromCenter(center: const Offset(82, 51), width: 11, height: 8),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    if (level >= 3) {
      final blush = Paint()..color = const Color(0xFFE8836B).withValues(alpha: 0.35);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(71, 51), width: 8, height: 5),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(90, 50), width: 6, height: 4),
        blush,
      );
    }
  }

  void _paintCarriedLeaf(Canvas canvas, double wave) {
    canvas.save();
    canvas.translate(28, 26 + wave * 0.8);
    canvas.rotate(-0.35 + wave * 0.04);
    _drawLeaf(canvas, width: 46, height: 24);
    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, {required double width, required double height}) {
    final path = Path()
      ..moveTo(-width / 2, 0)
      ..quadraticBezierTo(0, -height, width / 2, 0)
      ..quadraticBezierTo(0, height, -width / 2, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = palette.leaf);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.leafDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(-width / 2 + 3, 0),
      Offset(width / 2 - 3, 0),
      Paint()
        ..color = palette.leafLight
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    for (var i = -1; i <= 1; i++) {
      final x = i * width * 0.2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + width * 0.1, -height * 0.36),
        Paint()
          ..color = palette.leafLight.withValues(alpha: 0.8)
          ..strokeWidth = 1,
      );
    }
  }

  void _paintAccessories(Canvas canvas) {
    if (level >= 3) _paintCap(canvas);
    if (level >= 4) _paintScarf(canvas);
    if (level >= 5) _paintCrown(canvas);
  }

  void _paintCap(Canvas canvas) {
    if (level >= 5) return;

    final cap = Path()
      ..moveTo(66, 36)
      ..quadraticBezierTo(78, 20, 92, 34)
      ..quadraticBezierTo(78, 30, 66, 36)
      ..close();

    canvas.drawPath(cap, Paint()..color = palette.leafDark);
    canvas.drawPath(
      cap,
      Paint()
        ..color = palette.leafLight.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _paintScarf(Canvas canvas) {
    final scarf = Paint()..color = palette.glow;
    canvas.drawPath(
      Path()
        ..moveTo(64, 56)
        ..quadraticBezierTo(70, 64, 78, 60)
        ..quadraticBezierTo(70, 68, 62, 62)
        ..close(),
      scarf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(63, 60)
        ..lineTo(58, 72)
        ..lineTo(65, 70)
        ..close(),
      Paint()..color = palette.glow.withValues(alpha: 0.8),
    );
  }

  void _paintCrown(Canvas canvas) {
    final crown = Path()
      ..moveTo(68, 34)
      ..lineTo(71, 22)
      ..lineTo(76, 30)
      ..lineTo(80, 19)
      ..lineTo(85, 29)
      ..lineTo(89, 23)
      ..lineTo(90, 34)
      ..close();

    canvas.drawPath(crown, Paint()..color = palette.glow);
    canvas.drawPath(
      crown,
      Paint()
        ..color = palette.glow.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(const Offset(80, 26), 1.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant AntPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.carryingLeaf != carryingLeaf ||
        oldDelegate.palette.isDark != palette.isDark;
  }
}

/// Folhinha isolada, usada como marcador da moeda visual do Formigueiro.
class LeafGlyph extends StatelessWidget {
  const LeafGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.62),
      painter: _LeafGlyphPainter(AnthillPalette.of(context)),
    );
  }
}

class _LeafGlyphPainter extends CustomPainter {
  _LeafGlyphPainter(this.palette);

  final AnthillPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(-size.width / 2, 0)
      ..quadraticBezierTo(0, -size.height, size.width / 2, 0)
      ..quadraticBezierTo(0, size.height, -size.width / 2, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = palette.leaf);
    canvas.drawLine(
      Offset(-size.width / 2 + 1, 0),
      Offset(size.width / 2 - 1, 0),
      Paint()
        ..color = palette.leafLight
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LeafGlyphPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark;
}
