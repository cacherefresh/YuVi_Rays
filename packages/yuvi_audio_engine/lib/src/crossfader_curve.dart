import 'dart:math' as math;

/// Linear gains for the left and right sides of a crossfader.
typedef CrossfaderGains = ({double left, double right});

/// Equal-power crossfade: both sides at ~0.707 (-3 dB) in the centre, so
/// perceived loudness stays constant across the throw.
///
/// [position] is 0.0 (full left) .. 1.0 (full right).
/// Pure function with no audio dependency, so it can be unit tested and
/// reused by any mixer.
CrossfaderGains equalPowerCrossfade(double position) {
  final x = position.clamp(0.0, 1.0);
  return (
    left: math.cos(x * math.pi / 2),
    right: math.cos((1.0 - x) * math.pi / 2),
  );
}
