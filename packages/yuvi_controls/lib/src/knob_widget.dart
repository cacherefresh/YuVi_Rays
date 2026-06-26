import 'dart:math' as math;
import 'package:flutter/material.dart';

class KnobWidget extends StatefulWidget {
  const KnobWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = const Color(0xFF00D4AA),
    this.size = 48.0,
    this.sensitivity = 150.0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;
  final double size;
  final double sensitivity;

  @override
  State<KnobWidget> createState() => _KnobWidgetState();
}

class _KnobWidgetState extends State<KnobWidget> {
  double _startY = 0;
  double _startValue = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: (d) {
            _startY = d.globalPosition.dy;
            _startValue = widget.value;
          },
          onPanUpdate: (d) {
            final delta = (_startY - d.globalPosition.dy) / widget.sensitivity;
            widget.onChanged((_startValue + delta).clamp(0.0, 1.0));
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _KnobPainter(value: widget.value, color: widget.color),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter({required this.value, required this.color});

  final double value;
  final Color color;

  static const _startAngle = 0.75 * math.pi; // 135°
  static const _sweepTotal = 1.5 * math.pi;  // 270° arc

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;

    // Track arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      _startAngle,
      _sweepTotal,
      false,
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        _startAngle,
        _sweepTotal * value,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Knob body
    canvas.drawCircle(
      center,
      radius - 8,
      Paint()..color = const Color(0xFF2C2C2E),
    );

    // Indicator dot
    final angle = _startAngle + _sweepTotal * value;
    final dotOffset = Offset(
      center.dx + (radius - 14) * math.cos(angle),
      center.dy + (radius - 14) * math.sin(angle),
    );
    canvas.drawCircle(dotOffset, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.value != value || old.color != color;
}
