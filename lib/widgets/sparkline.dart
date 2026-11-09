import 'package:flutter/material.dart';
import '../config/colors.dart';

class Sparkline extends StatelessWidget {
  final List<double> values;
  final double minY;
  final double maxY;
  final Color color;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.minY = 1,
    this.maxY = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Center(
        child: Text(
          'Not enough data',
          style: TextStyle(color: context.colors.textFaint, fontSize: 12),
        ),
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(values, minY, maxY, color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double minY, maxY;
  final Color color;

  _SparklinePainter(this.values, this.minY, this.maxY, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 2.0;
    final w = size.width;
    final h = size.height - pad * 2;
    final dx = w / (values.length - 1);

    double yFor(double v) {
      final t = ((v - minY) / (maxY - minY)).clamp(0.0, 1.0);
      return pad + h - t * h;
    }

    final line = Path()..moveTo(0, yFor(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(i * dx, yFor(values[i]));
    }

    final fill = Path.from(line)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.35),
            AppColors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}