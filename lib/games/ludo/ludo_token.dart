import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';

class LudoTokenPainter extends CustomPainter {
  LudoTokenPainter({
    required this.color,
    required this.highlighted,
    required this.pulse,
    this.stackCount = 1,
  });

  final Color color;
  final bool highlighted;
  final double pulse;
  final int stackCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    if (highlighted) {
      canvas.drawCircle(
        center,
        radius + size.width * (0.10 + 0.06 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.06
          ..color = color.withOpacity(0.35 + 0.45 * pulse),
      );
    }

    canvas.drawCircle(
      Offset(center.dx, center.dy + size.width * 0.04),
      radius,
      Paint()..color = const Color(0x1A000000),
    );

    final grad = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 1.0,
      colors: [
        Color.lerp(color, Colors.white, 0.35)!,
        color,
        Color.lerp(color, Colors.black, 0.25)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final bodyPaint = Paint()
      ..shader = grad.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bodyPaint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(0.85),
    );

    final gemCenter = Offset(center.dx, center.dy - radius * 0.15);
    final gemRadius = radius * 0.42;
    final gemGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: [
        Colors.white,
        Color.lerp(color, Colors.white, 0.5)!,
        color,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(
      gemCenter,
      gemRadius,
      Paint()..shader = gemGrad.createShader(Rect.fromCircle(center: gemCenter, radius: gemRadius)),
    );
    canvas.drawCircle(
      gemCenter,
      gemRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.6),
    );

    final hlCenter = Offset(gemCenter.dx - gemRadius * 0.3, gemCenter.dy - gemRadius * 0.3);
    canvas.drawCircle(hlCenter, gemRadius * 0.25, Paint()..color = Colors.white.withOpacity(0.7));

    if (stackCount > 1) {
      final badgeCenter = Offset(center.dx + radius * 0.7, center.dy - radius * 0.7);
      final badgeRadius = size.width * 0.14;
      canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = AppTokens.text);
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$stackCount',
          style: TextStyle(
            color: Colors.white,
            fontSize: badgeRadius * 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(LudoTokenPainter old) =>
      old.color != color ||
      old.highlighted != highlighted ||
      old.pulse != pulse ||
      old.stackCount != stackCount;
}
