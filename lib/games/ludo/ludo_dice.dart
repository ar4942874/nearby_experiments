import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearby_chat_app/design_tokens.dart';

class LudoDice extends StatefulWidget {
  const LudoDice({
    super.key,
    required this.value,
    required this.dimmed,
    required this.onRoll,
    required this.canRoll,
    required this.activeColor,
  });

  final int value;
  final bool dimmed;
  final VoidCallback onRoll;
  final bool canRoll;
  final Color activeColor;

  @override
  State<LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<LudoDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: AppTokens.motionSlow,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.selectionClick();
      }
    });

  @override
  void didUpdateWidget(covariant LudoDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value > 0) {
      _tumble.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: _tumble,
            builder: (context, _) {
              final rolling = _tumble.isAnimating;
              final face = rolling
                  ? 1 + (_tumble.value * 12).floor() % 6
                  : widget.value;
              final scale = 1.0 + 0.10 * math.sin(math.pi * (rolling ? _tumble.value : 0.0));
              return Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: widget.canRoll
                            ? widget.activeColor.withOpacity(0.4)
                            : AppTokens.border,
                        width: 1.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.canRoll
                            ? widget.activeColor.withOpacity(0.15)
                            : const Color(0x0A000000),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _DicePainter(face, dimmed: widget.dimmed),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTokens.sm),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: widget.canRoll ? widget.onRoll : null,
            icon: Icon(
              Icons.casino_rounded,
              size: 20,
              color: widget.canRoll ? Colors.white : Colors.grey.shade400,
            ),
            label: Text(
              'ROLL DICE',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.canRoll ? Colors.white : Colors.grey.shade400,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.canRoll ? widget.activeColor : AppTokens.border,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tumble.dispose();
    super.dispose();
  }
}

class _DicePainter extends CustomPainter {
  _DicePainter(this.value, {this.dimmed = false});

  final int value;
  final bool dimmed;

  static const Map<int, List<int>> _faces = {
    1: [5],
    2: [3, 7],
    3: [3, 5, 7],
    4: [1, 3, 7, 9],
    5: [1, 3, 5, 7, 9],
    6: [1, 3, 4, 6, 7, 9],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pipR = size.width * 0.09;
    if (value < 1 || value > 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            color: dimmed ? Colors.grey.shade300 : Colors.grey.shade400,
            fontSize: size.height * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final pipColor = dimmed
        ? AppTokens.text.withOpacity(0.30)
        : AppTokens.text;
    for (final i in _faces[value]!) {
      final row = (i - 1) ~/ 3;
      final col = (i - 1) % 3;
      final center = Offset(
        size.width * (col + 0.5) / 3,
        size.height * (row + 0.5) / 3,
      );
      canvas.drawCircle(center, pipR, Paint()..color = pipColor);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) =>
      old.value != value || old.dimmed != dimmed;
}
