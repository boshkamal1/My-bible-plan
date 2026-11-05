import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A candle that lights up when the home page appears, then gently flickers.
class StreakCandle extends StatefulWidget {
  const StreakCandle({super.key, this.size = 40});

  final double size;

  @override
  State<StreakCandle> createState() => _StreakCandleState();
}

class _StreakCandleState extends State<StreakCandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flame.stop();
      _flame.value = 0.65;
    } else if (!_flame.isAnimating) {
      _flame.repeat();
    }
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Streak candle',
        image: true,
        child: AnimatedBuilder(
          animation: _flame,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _CandlePainter(_flame.value),
          ),
        ),
      );
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter(this.time);

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);

    final glow = Paint()
      ..color = const Color(0xFFFFAD35)
          .withValues(alpha: .14 + .06 * math.sin(time * 2 * math.pi));
    canvas.drawCircle(const Offset(20, 13), 12, glow);

    // Candle, wax edge and wick stay still while the flame moves.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, 20, 14, 18), const Radius.circular(3)),
      Paint()..color = const Color(0xFFF4DFAD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(23, 21, 2, 16), const Radius.circular(1)),
      Paint()..color = const Color(0xFFD1A968),
    );
    canvas.drawLine(
        const Offset(20, 21),
        const Offset(20, 16),
        Paint()
          ..color = const Color(0xFF59412D)
          ..strokeWidth = 1.5);

    final rise = (time / .24).clamp(0.0, 1.0);
    final sway = math.sin(time * 2 * math.pi) * 1.1;
    canvas.save();
    canvas.translate(sway, (1 - rise) * 5);
    canvas.translate(20, 16);
    canvas.scale(.65 + .35 * rise,
        .55 + .45 * rise + .04 * math.sin(time * 2 * math.pi));
    canvas.translate(-20, -16);
    final outer = Path()
      ..moveTo(20, 2)
      ..cubicTo(27, 9, 28, 14, 23, 18)
      ..quadraticBezierTo(20, 21, 17, 18)
      ..cubicTo(12, 14, 16, 8, 20, 2);
    canvas.drawPath(outer, Paint()..color = const Color(0xFFFF922E));
    final inner = Path()
      ..moveTo(20, 9)
      ..quadraticBezierTo(24, 15, 21, 18)
      ..quadraticBezierTo(17, 18, 18, 14)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFE38B));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) =>
      oldDelegate.time != time;
}
