import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/src/pitch_math.dart';

void main() {
  test('percent maps to playback rate', () {
    expect(playbackRateForPercent(0), 1.0);
    expect(playbackRateForPercent(16), closeTo(1.16, 1e-12));
    expect(playbackRateForPercent(-16), closeTo(0.84, 1e-12));
  });

  test('semitones for the ±16% range', () {
    expect(semitonesForPercent(0), 0);
    expect(semitonesForPercent(16), closeTo(2.57, 0.01));
    expect(semitonesForPercent(-16), closeTo(-3.02, 0.01));
  });

  test('rate never reaches zero', () {
    expect(playbackRateForPercent(-100), greaterThan(0));
  });
}
