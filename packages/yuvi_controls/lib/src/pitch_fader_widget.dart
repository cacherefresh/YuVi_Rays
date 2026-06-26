import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Horizontal pitch/BPM adjust fader.
/// [value] is in semitones (clamped to ±[maxSemitones]).
/// Displays a live BPM-rate percentage next to the label.
class PitchFaderWidget extends StatefulWidget {
  const PitchFaderWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxSemitones = 7.0,
    this.color = const Color(0xFF00D4AA),
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double maxSemitones;
  final Color color;

  @override
  State<PitchFaderWidget> createState() => _PitchFaderWidgetState();
}

class _PitchFaderWidgetState extends State<PitchFaderWidget> {
  double _startX = 0;
  double _startValue = 0;

  // 2^(s/12) gives the playback-rate multiplier for s semitones.
  // BPM offset % = (rate − 1) × 100.
  static String _bpmPct(double semitones) {
    final rate = math.pow(2.0, semitones / 12.0) as double;
    final pct = (rate - 1.0) * 100.0;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final normalized =
        (widget.value + widget.maxSemitones) / (2 * widget.maxSemitones);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label row: PITCH  +00.00%  [RST]
        Row(
          children: [
            Text(
              'PITCH',
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _bpmPct(widget.value),
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onChanged(0.0),
              child: Text(
                'RST',
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Fader track
        GestureDetector(
          onPanStart: (d) {
            _startX = d.globalPosition.dx;
            _startValue = widget.value;
          },
          onPanUpdate: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            // Normalize drag delta against the full widget width.
            final delta = (d.globalPosition.dx - _startX) / box.size.width;
            final newVal = _startValue + delta * 2 * widget.maxSemitones;
            widget.onChanged(
              newVal.clamp(-widget.maxSemitones, widget.maxSemitones),
            );
          },
          child: SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _PitchFaderPainter(
                normalized: normalized,
                color: widget.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PitchFaderPainter extends CustomPainter {
  const _PitchFaderPainter({required this.normalized, required this.color});

  final double normalized; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;
    final trackY = size.height / 2;
    const trackH = 4.0;

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY - trackH / 2, size.width, trackH),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF3A3A3C),
    );

    // Fill from center to thumb
    final thumbX = normalized * size.width;
    final fillLeft = thumbX < midX ? thumbX : midX;
    final fillWidth = (thumbX - midX).abs();
    if (fillWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(fillLeft, trackY - trackH / 2, fillWidth, trackH),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: 0.5),
      );
    }

    // Center zero tick
    canvas.drawLine(
      Offset(midX, trackY - 6),
      Offset(midX, trackY + 6),
      Paint()
        ..color = const Color(0xFF636366)
        ..strokeWidth = 1,
    );

    // Thumb body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(thumbX - 6, trackY - 10, 12, 20),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF4A4A4C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(thumbX - 6, trackY - 10, 12, 20),
        const Radius.circular(3),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Thumb center line
    canvas.drawLine(
      Offset(thumbX, trackY - 5),
      Offset(thumbX, trackY + 5),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PitchFaderPainter old) =>
      old.normalized != normalized || old.color != color;
}
