import 'dart:math' as math;

/// Pitch helpers. Pitch is a speed change in percent, like a turntable's
/// pitch fader. With no key lock, speed and key change together.

/// Playback-rate multiplier for a speed change in [percent].
/// +4% → 1.04. Never returns less than 0.01.
double playbackRateForPercent(double percent) =>
    math.max(0.01, 1.0 + percent / 100.0);

/// How far the key moves, in semitones, at a speed change of [percent].
/// +16% ≈ +2.57 st, −16% ≈ −3.02 st.
double semitonesForPercent(double percent) =>
    12.0 * math.log(playbackRateForPercent(percent)) / math.ln2;
