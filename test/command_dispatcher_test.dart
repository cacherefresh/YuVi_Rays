// The dispatcher applies input commands to the mixer contract. Runs on the
// Dart VM against the fake mixer, so it runs in CI.
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_input/yuvi_input.dart';
import 'package:yuvi_rays/input/command_dispatcher.dart';

import 'support/fake_mixer.dart';

void main() {
  late FakeMixer mixer;
  late CommandDispatcher dispatch;
  setUp(() {
    mixer = FakeMixer();
    dispatch = CommandDispatcher(mixer);
  });

  group('headphone cue', () {
    test('ToggleHeadphoneCue switches only that deck, on then off', () {
      dispatch(const ToggleHeadphoneCue('A'));
      expect(mixer.decks['A']!.headphoneCue, isTrue);
      expect(mixer.decks['B']!.headphoneCue, isFalse);
      dispatch(const ToggleHeadphoneCue('A'));
      expect(mixer.decks['A']!.headphoneCue, isFalse);
      expect(mixer.decks['A']!.log, ['pflOn', 'pflOff']);
    });

    test('both decks can be cued at once', () {
      dispatch(const ToggleHeadphoneCue('A'));
      dispatch(const ToggleHeadphoneCue('B'));
      expect(mixer.decks.values.every((d) => d.headphoneCue), isTrue);
    });

    test('SetHeadphoneMix sets the mix and leaves the level alone', () {
      dispatch(const SetHeadphoneMix(0.0));
      expect(mixer.headphoneMix, 0.0);
      expect(mixer.headphoneVolume, 1);
    });

    test('SetHeadphoneMix with pick-up waits for the knob to reach the mix', () {
      dispatch(const SetHeadphoneMix(1.0, pickupTolerance: 0.03)); // far from 0.5
      expect(mixer.headphoneMix, 0.5);
      dispatch(const SetHeadphoneMix(0.51, pickupTolerance: 0.03)); // picked up
      expect(mixer.headphoneMix, 0.51);
    });
  });
}
