import 'dart:async';
import 'package:flutter/material.dart';

/// Pioneer DJ mixer-style master VU meter.
/// Shows two columns of LED segments (green → yellow → red) driven by a
/// [levelProvider] callback that returns the current RMS level in dBFS.
class VuMeterWidget extends StatefulWidget {
  const VuMeterWidget({
    super.key,
    required this.levelProvider,
    this.label = 'MASTER',
  });

  /// Called at ~30 fps; should return the combined output level in dBFS.
  /// Return -100 (or lower) when silent.
  final double Function() levelProvider;
  final String label;

  @override
  State<VuMeterWidget> createState() => _VuMeterWidgetState();
}

class _VuMeterWidgetState extends State<VuMeterWidget> {
  Timer? _ticker;
  double _level = -100;

  // Peak-hold: level stays visible for a short time after the peak drops
  double _peak = -100;
  int _peakHoldFrames = 0;
  static const _peakHoldDuration = 45; // ~1.5 s at 30 fps

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final raw = widget.levelProvider();
      setState(() {
        _level = raw;
        if (raw > _peak) {
          _peak = raw;
          _peakHoldFrames = _peakHoldDuration;
        } else if (_peakHoldFrames > 0) {
          _peakHoldFrames--;
        } else {
          _peak = (_peak - 1.5).clamp(-100.0, 12.0); // decay peak indicator
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _MeterColumns(level: _level, peak: _peak),
        ),
        const SizedBox(height: 4),
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF636366),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// The two-column LED display — mirrors a Pioneer DJM VU meter.
class _MeterColumns extends StatelessWidget {
  const _MeterColumns({required this.level, required this.peak});

  final double level;
  final double peak;

  // Segment thresholds in dBFS (bottom to top)
  static const _thresholds = <double>[
    -40, -35, -30, -24, -20, -16, -12, // 7 green
    -9,  -6,  -3,                       // 3 yellow
     0,   3,   6,                       // 3 red
  ];

  static const _segmentCount = 13;

  static Color _segmentColor(int index, bool lit) {
    if (!lit) {
      // Unlit: very dark tinted version of the segment's base colour
      if (index >= 10) return const Color(0xFF3A1010);
      if (index >= 7)  return const Color(0xFF2A2A10);
      return const Color(0xFF0D2010);
    }
    if (index >= 10) return const Color(0xFFFF3030); // red
    if (index >= 7)  return const Color(0xFFFFD000); // yellow
    return const Color(0xFF00E060);                  // green
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _column(),
        const SizedBox(width: 3),
        _column(),
      ],
    );
  }

  Widget _column() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_segmentCount, (rawIndex) {
          // Render top-to-bottom: index 0 in list = top = loudest segment
          final i = _segmentCount - 1 - rawIndex;
          final threshold = _thresholds[i];
          final lit = level >= threshold;
          final isPeak = peak >= threshold &&
              (i == _segmentCount - 1 || peak < _thresholds[i + 1]);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: isPeak ? _segmentColor(i, true).withValues(alpha: 0.6) : _segmentColor(i, lit),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }
}
