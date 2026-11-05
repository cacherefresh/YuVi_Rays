import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';
import 'package:yuvi_audio_engine/src/models/deck_state.dart';
import 'package:yuvi_audio_engine/src/models/master_state.dart';

void main() {
  group('DeckState.headphoneCue', () {
    test('starts off and notifies when switched', () {
      final s = DeckState('A');
      var notified = 0;
      s.addListener(() => notified++);
      expect(s.headphoneCue, isFalse);
      s.update(headphoneCue: true);
      expect(s.headphoneCue, isTrue);
      s.update(headphoneCue: true); // no change, no notification
      expect(notified, 1);
    });
  });

  group('MasterState.headphoneMix', () {
    test('starts in the centre and notifies on change', () {
      final m = MasterState();
      var notified = 0;
      m.addListener(() => notified++);
      expect(m.headphoneMix, 0.5);
      m.update(headphoneMix: 0.0);
      expect(m.headphoneMix, 0.0);
      expect(notified, 1);
    });
  });

  group('headphone mix curve (shared with the crossfader)', () {
    test('full left is cue only, full right is master only', () {
      final cueOnly = equalPowerCrossfade(0);
      expect(cueOnly.left, closeTo(1, 1e-9));
      expect(cueOnly.right, closeTo(0, 1e-9));
      final masterOnly = equalPowerCrossfade(1);
      expect(masterOnly.left, closeTo(0, 1e-9));
      expect(masterOnly.right, closeTo(1, 1e-9));
    });
  });

  group('HeadphoneStatus.parse', () {
    test('known names, and unknown ones become error', () {
      expect(HeadphoneStatus.parse('playing'), HeadphoneStatus.playing);
      expect(HeadphoneStatus.parse('waitingForClick'), HeadphoneStatus.waitingForClick);
      expect(HeadphoneStatus.parse('nonsense'), HeadphoneStatus.error);
    });
  });

  test('OutputDevicesFound.namesHidden', () {
    const hidden = OutputDevicesFound([AudioOutputDevice(id: 'x', name: 'Unnamed output')]);
    const named = OutputDevicesFound([AudioOutputDevice(id: 'x', name: 'USB Audio')]);
    expect(hidden.namesHidden, isTrue);
    expect(named.namesHidden, isFalse);
  });
}
