import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/src/models/deck_state.dart';
import 'package:yuvi_track_metadata/yuvi_track_metadata.dart';

void main() {
  test('Serato slots 0-3 fill the 4 hot cues; slots 4-7 are ignored', () {
    final d = DeckState('A')
      ..setHotCues({
        0: const HotCue(position: Duration(seconds: 1)),
        3: const HotCue(position: Duration(seconds: 4)),
        6: const HotCue(position: Duration(seconds: 7)),
      });
    expect(d.hotCues.map((c) => c?.seconds), [1, null, null, 4]);
  });

  test('set and clear one slot', () {
    final d = DeckState('A')..setHotCue(1, const HotCue(position: Duration(milliseconds: 2500)));
    expect(d.hotCues[1]!.seconds, 2.5);
    d.setHotCue(1, null);
    expect(d.hotCues[1], isNull);
  });

  test('out-of-range slots are ignored', () {
    final d = DeckState('A')..setHotCue(9, const HotCue(position: Duration.zero));
    expect(d.hotCues, everyElement(isNull));
  });
}
