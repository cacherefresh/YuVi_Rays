import 'dart:math' as math;
import 'package:flutter/material.dart';

class TurntablePainter extends CustomPainter {
  const TurntablePainter({
    required this.waveformData,
    required this.position,
    required this.isPlaying,
    required this.cuePoint,
    required this.accentColor,
    this.rotationAngle = 0.0,
  });

  final List<double> waveformData;
  final double position;
  final bool isPlaying;
  final double cuePoint;
  final Color accentColor;
  // Used only for the spinning disc label — the waveform ring and needle are
  // position-based so the needle stays stationary at 2 o'clock.
  final double rotationAngle;

  // 2 o'clock: 60° CW from 12 o'clock = −π/2 + π/3 = −π/6 in Flutter canvas
  static const _needleAngle = -math.pi / 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2 - 2;

    _drawVinyl(canvas, center, outerR);

    if (waveformData.isNotEmpty) {
      _drawWaveformRing(canvas, center, outerR);
    }

    _drawCenterLabel(canvas, center, outerR);

    // Needle drawn last so it renders on top of everything
    _drawPositionNeedle(canvas, center, outerR);
    if (cuePoint > 0) _drawCueMark(canvas, center, outerR);
  }

  void _drawVinyl(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF151515));

    final groovePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (double r = radius * 0.38; r < radius * 0.88; r += radius * 0.035) {
      canvas.drawCircle(center, r, groovePaint);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawWaveformRing(Canvas canvas, Offset center, double outerR) {
    final n = waveformData.length;
    final waveInnerR = outerR * 0.52;
    final waveOuterR = outerR * 0.88;
    final maxAmp = waveOuterR - waveInnerR;

    for (int i = 0; i < n; i++) {
      final samplePos = i / n;
      // Circular distance from current position (0 = at needle).
      // 0..0.5 = upcoming (CCW of needle, approaching), 0.5..1 = already played (CW of needle, receding).
      final relDelta = (samplePos - position + 1.0) % 1.0;

      // Map relDelta to angle so that:
      //  relDelta=0   → _needleAngle (current position, white bar at needle)
      //  relDelta=0.1 → slightly CW of needle (upcoming, approaches from CW as disc rotates CCW)
      //  relDelta=0.9 → slightly CCW of needle (just played, moved CCW past needle)
      final angle = _needleAngle + relDelta * 2 * math.pi;

      final amplitude = waveformData[i].clamp(0.0, 1.0);

      final Color barColor;
      if (relDelta < 0.008) {
        barColor = Colors.white;
      } else if (relDelta >= 0.5) {
        barColor = accentColor;
      } else {
        barColor = accentColor.withValues(alpha: 0.25);
      }

      final p1 = Offset(
        center.dx + waveInnerR * math.cos(angle),
        center.dy + waveInnerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (waveInnerR + amplitude * maxAmp) * math.cos(angle),
        center.dy + (waveInnerR + amplitude * maxAmp) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, Paint()..color = barColor..strokeWidth = 1.2);
    }
  }

  void _drawCenterLabel(Canvas canvas, Offset center, double outerR) {
    final labelR = outerR * 0.36;
    canvas.drawCircle(center, labelR, Paint()..color = const Color(0xFF252527));
    canvas.drawCircle(
      center,
      labelR,
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Small orbiting dot at rotationAngle so the disc visually appears to spin
    // even though the waveform ring is position-based (not rotation-based).
    final dotAngle = -rotationAngle; // negative → CCW rotation matches waveform direction
    final dotR = labelR * 0.65;
    final dotPt = Offset(
      center.dx + dotR * math.cos(dotAngle),
      center.dy + dotR * math.sin(dotAngle),
    );
    canvas.drawCircle(dotPt, 2.5, Paint()..color = const Color(0xFF4A4A4C));

    // Spindle
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF3A3A3C));
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF1C1C1E));
  }

  // Needle is drawn at a FIXED 2 o'clock angle regardless of position or rotation.
  void _drawPositionNeedle(Canvas canvas, Offset center, double outerR) {
    const angle = _needleAngle;
    final waveInnerR = outerR * 0.50;

    // Outer glow
    canvas.drawLine(
      Offset(center.dx + waveInnerR * math.cos(angle), center.dy + waveInnerR * math.sin(angle)),
      Offset(center.dx + outerR * 0.93 * math.cos(angle), center.dy + outerR * 0.93 * math.sin(angle)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 4.0,
    );
    // Core line
    canvas.drawLine(
      Offset(center.dx + waveInnerR * math.cos(angle), center.dy + waveInnerR * math.sin(angle)),
      Offset(center.dx + outerR * 0.93 * math.cos(angle), center.dy + outerR * 0.93 * math.sin(angle)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );
  }

  void _drawCueMark(Canvas canvas, Offset center, double outerR) {
    // Cue dot is offset from needle by the cue-to-current position difference
    final relCueDelta = (cuePoint - position + 1.0) % 1.0;
    final angle = _needleAngle + relCueDelta * 2 * math.pi;
    final cueR = outerR * 0.91;
    canvas.drawCircle(
      Offset(center.dx + cueR * math.cos(angle), center.dy + cueR * math.sin(angle)),
      4,
      Paint()..color = const Color(0xFFFF9500),
    );
  }

  @override
  bool shouldRepaint(TurntablePainter old) {
    return old.position != position ||
        old.rotationAngle != rotationAngle ||
        old.waveformData != waveformData ||
        old.isPlaying != isPlaying ||
        old.cuePoint != cuePoint;
  }
}
