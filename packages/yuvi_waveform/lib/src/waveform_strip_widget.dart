import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

class WaveformStripWidget extends StatelessWidget {
  const WaveformStripWidget({
    super.key,
    required this.state,
    required this.accentColor,
    this.windowSeconds = 6.0,
    this.height = 56.0,
    this.onSeek,
  });

  final DeckState state;
  final Color accentColor;
  final double windowSeconds;
  final double height;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        if (onSeek == null || state.duration <= 0) return;
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(d.globalPosition);
        final clickFraction = local.dx / box.size.width;
        final halfWindow = windowSeconds / 2;
        final center = state.position * state.duration;
        final seekSeconds = (center - halfWindow) + clickFraction * windowSeconds;
        final normalized = (seekSeconds / state.duration).clamp(0.0, 1.0);
        onSeek!(normalized);
      },
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _WaveformStripPainter(
            waveformData: state.waveformData,
            position: state.position,
            duration: state.duration,
            cuePoint: state.cuePoint,
            windowSeconds: windowSeconds,
            playedColor: accentColor,
            unplayedColor: accentColor.withValues(alpha: 0.25),
            cueColor: const Color(0xFFFF9500),
          ),
        ),
      ),
    );
  }
}

class _WaveformStripPainter extends CustomPainter {
  const _WaveformStripPainter({
    required this.waveformData,
    required this.position,
    required this.duration,
    required this.cuePoint,
    required this.windowSeconds,
    required this.playedColor,
    required this.unplayedColor,
    required this.cueColor,
  });

  final List<double> waveformData;
  final double position;
  final double duration;
  final double cuePoint;
  final double windowSeconds;
  final Color playedColor;
  final Color unplayedColor;
  final Color cueColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1A1A1C));

    if (waveformData.isEmpty || duration <= 0) {
      _drawEmptyState(canvas, size);
      return;
    }

    final n = waveformData.length;
    final samplesPerSec = n / duration;
    final halfWindowSamples = windowSeconds / 2 * samplesPerSec;
    final centerSample = position * n;

    for (int px = 0; px < size.width.toInt(); px++) {
      final sampleF = centerSample - halfWindowSamples + (px / size.width) * windowSeconds * samplesPerSec;
      final sampleI = sampleF.round();

      if (sampleI < 0 || sampleI >= n) continue;

      final amplitude = waveformData[sampleI].clamp(0.0, 1.0);
      final barH = amplitude * size.height * 0.42;
      final midY = size.height / 2;

      final isPlayed = sampleI < centerSample;
      final isCue = (sampleI / n - cuePoint).abs() < 0.003;

      final barColor = isCue ? cueColor : (isPlayed ? playedColor : unplayedColor);

      canvas.drawLine(
        Offset(px.toDouble(), midY - barH),
        Offset(px.toDouble(), midY + barH),
        Paint()..color = barColor..strokeWidth = 1,
      );
    }

    // Center position line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()..color = Colors.white..strokeWidth = 1.5,
    );

    // Cue marker
    if (cuePoint > 0) {
      final cueSampleF = cuePoint * n;
      final cueRelOffset = (cueSampleF - centerSample) / (halfWindowSamples * 2);
      final cuePx = (cueRelOffset + 0.5) * size.width;
      if (cuePx >= 0 && cuePx <= size.width) {
        canvas.drawLine(
          Offset(cuePx, 0),
          Offset(cuePx, size.height),
          Paint()..color = cueColor..strokeWidth = 1.5,
        );
        // Cue triangle marker
        final path = Path()
          ..moveTo(cuePx, 0)
          ..lineTo(cuePx - 5, 0)
          ..lineTo(cuePx, 8)
          ..close();
        canvas.drawPath(path, Paint()..color = cueColor);
      }
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()..color = const Color(0xFF4A4A4C)..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformStripPainter old) {
    return old.position != position ||
        old.cuePoint != cuePoint ||
        old.waveformData != waveformData;
  }
}
