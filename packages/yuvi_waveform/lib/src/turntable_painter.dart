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
  final double rotationAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2 - 2;

    _drawVinyl(canvas, center, outerR);

    if (waveformData.isNotEmpty) {
      _drawWaveformRing(canvas, center, outerR);
    }

    _drawCenterLabel(canvas, center, outerR);
    _drawPositionNeedle(canvas, center, outerR);
    if (cuePoint > 0) _drawCueMark(canvas, center, outerR);
  }

  void _drawVinyl(Canvas canvas, Offset center, double radius) {
    // Background disc
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF151515));

    // Concentric groove rings
    final groovePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (double r = radius * 0.38; r < radius * 0.88; r += radius * 0.035) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Rim highlight
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
      // Rotate so current position is at top (−π/2)
      final angle = (i / n) * 2 * math.pi - math.pi / 2 + rotationAngle;
      final amplitude = waveformData[i].clamp(0.0, 1.0);

      final samplePos = i / n;
      final Color barColor;
      // relDelta measures how far this sample is *ahead* of the current position
      // in circular terms (0 = at position, 0.5 = half track ahead, ~1 = just behind).
      // Already-played samples sit behind the needle: relDelta > 0.5.
      // Upcoming samples are ahead of the needle: relDelta < 0.5.
      final relDelta = (samplePos - position + 1.0) % 1.0;
      if (relDelta < 0.008) {
        barColor = Colors.white; // current position marker
      } else if (relDelta >= 0.5) {
        barColor = accentColor; // already played
      } else {
        barColor = accentColor.withValues(alpha: 0.25); // upcoming
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
    // Spindle hole
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF3A3A3C));
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF1C1C1E));
  }

  void _drawPositionNeedle(Canvas canvas, Offset center, double outerR) {
    final angle = position * 2 * math.pi - math.pi / 2 + rotationAngle;
    final tip = Offset(
      center.dx + outerR * 0.91 * math.cos(angle),
      center.dy + outerR * 0.91 * math.sin(angle),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );
  }

  void _drawCueMark(Canvas canvas, Offset center, double outerR) {
    final angle = cuePoint * 2 * math.pi - math.pi / 2 + rotationAngle;
    final cueR = outerR * 0.91;
    final p = Offset(
      center.dx + cueR * math.cos(angle),
      center.dy + cueR * math.sin(angle),
    );
    canvas.drawCircle(
      p,
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
