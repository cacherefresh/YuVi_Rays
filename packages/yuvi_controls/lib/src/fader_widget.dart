import 'package:flutter/material.dart';

// StatefulWidget so we can track drag start values correctly.
// Using delta-based dragging avoids the coordinate-system mismatch that
// comes from context.findRenderObject() returning the outer Column's
// RenderBox instead of the fader track's RenderBox.
class FaderWidget extends StatefulWidget {
  const FaderWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 28.0,
    this.height = 160.0,
    this.color = const Color(0xFF00D4AA),
    this.label = 'VOL',
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double width;
  final double height;
  final Color color;
  final String label;

  @override
  State<FaderWidget> createState() => _FaderWidgetState();
}

class _FaderWidgetState extends State<FaderWidget> {
  double _startY = 0;
  double _startValue = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onPanStart: (d) {
            _startY = d.globalPosition.dy;
            _startValue = widget.value;
          },
          onPanUpdate: (d) {
            final delta = (_startY - d.globalPosition.dy) / widget.height;
            widget.onChanged((_startValue + delta).clamp(0.0, 1.0));
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _FaderPainter(value: widget.value, color: widget.color),
            ),
          ),
        ),
      ],
    );
  }
}

class _FaderPainter extends CustomPainter {
  const _FaderPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const trackW = 4.0;

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - trackW / 2, 8, trackW, size.height - 16),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF3A3A3C),
    );

    // Filled portion (bottom → value position)
    final fillTop = size.height - 8 - (size.height - 16) * value;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - trackW / 2, fillTop, trackW, size.height - 8 - fillTop),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.5),
    );

    // Thumb
    final thumbY = size.height - 8 - (size.height - 16) * value;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, thumbY - 6, 20, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF4A4A4C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, thumbY - 6, 20, 12),
        const Radius.circular(3),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Thumb center line
    canvas.drawLine(
      Offset(cx - 6, thumbY),
      Offset(cx + 6, thumbY),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FaderPainter old) => old.value != value || old.color != color;
}
