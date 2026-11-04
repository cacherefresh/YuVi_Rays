import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/src/models/deck_state.dart';

void main() {
  test('current BPM is the base BPM times the pitch speed', () {
    final d = DeckState('A')..setBpm(detected: 120, tag: null);
    expect(d.currentBpm, 120);
    d.update(pitchCoarse: 4.0635, pitchFine: -0.25);
    expect(d.currentBpm, closeTo(120 * 1.038135, 1e-4));
  });

  test('detected BPM wins by default; tag wins when preferred', () {
    final d = DeckState('A')..setBpm(detected: 150, tag: 75);
    expect(d.baseBpm, 150);
    d.setPreferTagBpm(true);
    expect(d.baseBpm, 75);
  });

  test('each source falls back to the other when missing', () {
    final d = DeckState('A')..setBpm(detected: null, tag: 128);
    expect(d.baseBpm, 128);
    d
      ..setPreferTagBpm(true)
      ..setBpm(detected: 140, tag: null);
    expect(d.baseBpm, 140);
  });

  test('no BPM at all gives null', () {
    expect(DeckState('A').currentBpm, isNull);
  });
}
