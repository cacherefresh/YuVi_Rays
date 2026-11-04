import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';

/// Horizontal pitch fader, in percent of speed (like a turntable).
///
/// [value] is the coarse pitch this fader controls, clamped to ±[range]%.
/// The readout shows [totalPercent] (coarse + any fine pitch) in both
/// percent and semitones, e.g. `+4.37%  +0.74 st`.
class PitchFaderWidget extends StatefulWidget {
  const PitchFaderWidget({
    super.key,
    required this.value,
    required this.onChanged,
    double? totalPercent,
    this.range = 16.0,
    this.color = const Color(0xFF00D4AA),
    this.showTempo = false,
    this.tempo,
  }) : totalPercent = totalPercent ?? value;

  /// Show the tempo readout line above the pitch label.
  final bool showTempo;

  /// Tempo in BPM as currently playing, or null when unknown (`---.--`).
  final double? tempo;

  /// Tempo readout colour: the same purple on every deck, at 75% opacity.
  static const tempoColor = Color(0xBFB388FF);

  /// Formats a BPM as 3 digits and 2 decimals: `124.35`, `098.20`.
  /// Null shows `---.--`.
  static String formatTempo(double? bpm) {
    if (bpm == null || bpm.isNaN || bpm.isInfinite) return '---.--';
    return bpm.toStringAsFixed(2).padLeft(6, '0');
  }

  final double value;
  final ValueChanged<double> onChanged;
  final double totalPercent;
  final double range;
  final Color color;

  @override
  State<PitchFaderWidget> createState() => _PitchFaderWidgetState();
}

class _PitchFaderWidgetState extends State<PitchFaderWidget> {
  double _startX = 0;
  double _startValue = 0;

  static String _signed(double v, int digits) =>
      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

  @override
  Widget build(BuildContext context) {
    final normalized =
        ((widget.value.clamp(-widget.range, widget.range) + widget.range) /
            (2 * widget.range));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTempo)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              PitchFaderWidget.formatTempo(widget.tempo),
              style: const TextStyle(
                color: PitchFaderWidget.tempoColor,
                fontSize: 10, // same font as the semitone readout
                fontFamily: 'monospace',
              ),
            ),
          ),
        // Label row: PITCH  +00.00%  +0.00 st  [RST]
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
              '${_signed(widget.totalPercent, 2)}%',
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_signed(semitonesForPercent(widget.totalPercent), 2)} st',
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.7),
                fontSize: 10,
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
            final newVal = _startValue + delta * 2 * widget.range;
            widget.onChanged(newVal.clamp(-widget.range, widget.range));
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
