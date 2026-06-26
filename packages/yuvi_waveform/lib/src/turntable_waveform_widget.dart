import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';
import 'turntable_painter.dart';

class TurntableWaveformWidget extends StatefulWidget {
  const TurntableWaveformWidget({
    super.key,
    required this.state,
    required this.accentColor,
    this.onSeek,
  });

  final DeckState state;
  final Color accentColor;
  final ValueChanged<double>? onSeek;

  @override
  State<TurntableWaveformWidget> createState() => _TurntableWaveformWidgetState();
}

class _TurntableWaveformWidgetState extends State<TurntableWaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _rotationAngle = 0.0;
  double _lastPosition = 0.0;

  static const _rpmBase = 33.33;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..addListener(_onTick);
    widget.state.addListener(_onStateChange);
    _syncSpin();
  }

  @override
  void didUpdateWidget(TurntableWaveformWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onStateChange);
      widget.state.addListener(_onStateChange);
    }
    _syncSpin();
  }

  void _onStateChange() => setState(() => _syncSpin());

  void _syncSpin() {
    if (widget.state.isPlaying && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.state.isPlaying && _spin.isAnimating) {
      _spin.stop();
    }
  }

  void _onTick() {
    final currentPos = widget.state.position;
    final delta = currentPos - _lastPosition;
    _lastPosition = currentPos;

    // Large negative deltas mean the track was stopped/reset (position jumped
    // from ~1.0 back to 0). Ignore these to avoid the disc spinning backward.
    if (delta < -0.1) return;

    final radians = delta *
        2 *
        math.pi *
        (_rpmBase / 60) *
        (widget.state.duration > 0 ? widget.state.duration : 180);

    setState(() => _rotationAngle += radians);
  }

  @override
  void dispose() {
    _spin.removeListener(_onTick);
    _spin.dispose();
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onTapDown(TapDownDetails d) {
    if (widget.onSeek == null) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    // Angle from top (−π/2), converted to 0..1
    final angle = math.atan2(dy, dx) + math.pi / 2;
    final normalized = ((angle / (2 * math.pi)) + 1) % 1;
    widget.onSeek!(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTapDown: _onTapDown,
        child: CustomPaint(
          painter: TurntablePainter(
            waveformData: widget.state.waveformData,
            position: widget.state.position,
            isPlaying: widget.state.isPlaying,
            cuePoint: widget.state.cuePoint,
            accentColor: widget.accentColor,
            rotationAngle: _rotationAngle,
          ),
        ),
      ),
    );
  }
}
