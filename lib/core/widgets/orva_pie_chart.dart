import 'dart:math' as math;

import 'package:flutter/material.dart';

class OrvaPieSlice {
  const OrvaPieSlice({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

class OrvaPieChart extends StatelessWidget {
  const OrvaPieChart({
    super.key,
    required this.slices,
    this.size = 160,
    this.strokeWidth = 22,
    this.centerLabel,
  });

  final List<OrvaPieSlice> slices;
  final double size;
  final double strokeWidth;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrvaPiePainter(slices: slices, total: total, strokeWidth: strokeWidth),
        child: Center(
          child: Text(
            centerLabel ?? _format(total),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _format(double minutes) {
    final m = minutes.round();
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h${r}m';
  }
}

class _OrvaPiePainter extends CustomPainter {
  _OrvaPiePainter({required this.slices, required this.total, required this.strokeWidth});

  final List<OrvaPieSlice> slices;
  final double total;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, background);

    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OrvaPiePainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}
