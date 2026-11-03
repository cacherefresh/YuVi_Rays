// Fake MIDI test runner for the Akai MPK Mini Mk II.
//
// Runs on the Dart VM (no browser, no audio, no hardware), so it runs in CI
// on every pull request. It replays MIDI through the real profile file, the
// real mapper and the real dispatcher. Only the mixer is a fake.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_input/yuvi_input.dart';

import 'support/fake_midi_runner.dart';
import 'support/mpk_mini_mk2_sysex.dart';

const _profilePath = 'assets/midi_profiles/akai_mpk_mini_mk2.yaml';
const _fixtures = 'test/fixtures/mpk_mini_mk2';

void main() {
  late MidiProfile profile;
  setUp(() => profile = FakeMidiRunner.loadProfile(_profilePath));

  group('profile matches the real controller', () {
    final device = MpkMiniMk2Program.parseHexFile(
        File('$_fixtures/program_dump.txt').readAsStringSync());

    test('device dump decodes to the factory layout', () {
      expect(device.padChannel, 1);
      expect(device.knobCcs, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(device.padNotes.take(4), [44, 45, 46, 47]);
    });

    test('every knob in the profile is a real knob CC', () {
      for (final k in profile.knobs) {
        expect(device.knobCcs, contains(k.cc), reason: '${k.action.name} cc ${k.cc}');
      }
    });

    test('every pad in the profile is a real pad note on the pad channel', () {
      for (final p in profile.pads) {
        expect(device.padNotes, contains(p.note), reason: 'note ${p.note}');
        expect(p.channel, device.padChannel);
      }
    });

    test('bank A pads 1-4 are transport; bank B pads 1-8 are hot cues', () {
      final transport = profile.pads.where((p) => p.slot == null).map((p) => p.note);
      final hotCues = profile.pads.where((p) => p.slot != null).map((p) => p.note);
      expect(transport, device.padNotes.sublist(0, 4));
      expect(hotCues, device.padNotes.sublist(8, 16));
    });

    test('the profile is chosen for the device name Chrome reports', () {
      const fallback = MidiProfile(name: 'fallback');
      expect(MidiProfile.select('MPK Mini Mk II', [profile], fallback: fallback), same(profile));
    });
  });

  group('replaying a session: play, set cue, adjust pitch', () {
    late FakeMidiRunner run;
    setUp(() {
      run = FakeMidiRunner(profile: profile)
        ..playSessionFile('$_fixtures/session_play_cue_pitch.yaml');
    });

    test('pad 1 plays, pad 1 again pauses, pad 2 tap plays from cue', () {
      expect(run.mixer.decks['A']!.log, ['play', 'commitCue', 'pause', 'playFromCue']);
      expect(run.mixer.decks['A']!.isPlaying, isTrue);
    });

    test('K2 sets coarse pitch and K3 fine pitch, in percent', () {
      final a = run.mixer.decks['A']!;
      expect(a.pitchCoarse, closeTo(16 * (80 - 64) / 63, 1e-9)); // ≈ +4.06%
      expect(a.pitchFine, closeTo(-1 * (64 - 48) / 64, 1e-9));   // −0.25%
    });

    test('holding pad 2 sets the cue where the press began, not 1 s later', () {
      final a = run.mixer.decks['A']!;
      // Playing from t=0 to t=5 s. Pitch changed at about 1 s, so the
      // playhead at the press is a little over 5 s of track.
      final cueSeconds = a.cuePoint * a.durationSeconds;
      expect(cueSeconds, greaterThan(5.0));
      expect(cueSeconds, lessThan(5.3));
    });

    test('pad 2 tap jumped back to the cue, then kept playing', () {
      final a = run.mixer.decks['A']!;
      // Tap released at t=9.2 s; the session ends at t=10 s: 0.8 s of play
      // from the cue at a little over 1x speed.
      final played = a.seconds - a.cuePoint * a.durationSeconds;
      expect(played, closeTo(0.8 * a.playbackRate, 0.01));
    });

    test('K1 sets Deck A volume', () {
      expect(run.mixer.decks['A']!.volume, 1.0);
    });

    test('Deck B is untouched', () {
      final b = run.mixer.decks['B']!;
      expect(b.log, isEmpty);
      expect(b.pitchCoarse, 0);
    });
  });

  group('hot cues from bank B pads', () {
    test('first press sets, second press jumps back', () {
      final run = FakeMidiRunner(profile: profile);
      run.sendAt(Duration.zero, [144, 44, 100]); // pad 1 bank A: play
      run.sendAt(const Duration(seconds: 3), [144, 32, 100]); // bank B pad 1: set hot cue 1 at 3 s
      run.sendAt(const Duration(seconds: 3, milliseconds: 100), [128, 32, 0]);
      run.sendAt(const Duration(seconds: 8), [144, 32, 100]); // jump back to 3 s
      final a = run.mixer.decks['A']!;
      expect(a.log, ['play', 'setHotCue1', 'jumpHotCue1']);
      expect(a.hotCues[0], closeTo(3.0, 1e-9));
      expect(a.seconds, closeTo(3.0, 1e-9));
    });

    test('bank B top row drives Deck B', () {
      final run = FakeMidiRunner(profile: profile)..sendAt(Duration.zero, [144, 39, 100]);
      expect(run.mixer.decks['B']!.log, ['setHotCue4']);
      expect(run.mixer.decks['A']!.log, isEmpty);
    });
  });

  group('pick-up on the pitch knobs', () {
    test('a knob far from the deck pitch is ignored until it crosses it', () {
      final run = FakeMidiRunner(profile: profile);
      run.mixer.decks['A']!.pitchCoarse = 4.0; // set on screen
      run.sendAt(Duration.zero, [176, 2, 0]); //   knob at −16%: ignored
      expect(run.mixer.decks['A']!.pitchCoarse, 4.0);
      run.sendAt(const Duration(milliseconds: 50), [176, 2, 64]); // 0%: still below
      expect(run.mixer.decks['A']!.pitchCoarse, 4.0);
      run.sendAt(const Duration(milliseconds: 100), [176, 2, 90]); // ≈ +6.6%: crossed
      expect(run.mixer.decks['A']!.pitchCoarse, closeTo(16 * 26 / 63, 1e-9));
    });
  });
}
