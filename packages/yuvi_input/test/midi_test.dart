import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_input/yuvi_input.dart';

import 'support/fake_timers.dart';

const _profileYaml = '''
name: Test
device_name_contains: [MPK Mini]
knobs:
  - { cc: 1, action: channelVolume, deck: A }
  - { cc: 4, action: masterVolume }
  - { cc: 2, action: pitchCoarse, deck: A, min: -16, max: 16, takeover: pickup }
  - { cc: 3, action: pitchFine, deck: A, min: -1, max: 1 }
  - { cc: 20, channel: 2, action: crossfader }
pads:
  - { note: 44, deck: A, on_press: togglePlay }
  - { note: 45, deck: A, on_press: armCue, on_tap: playFromCue, on_hold: commitCue, hold_ms: 1000 }
  - { cc: 50, deck: B, on_press: stop }
''';

void main() {
  group('MidiMessage.parse', () {
    test('note on, channel 10', () {
      final m = MidiMessage.parse([0x99, 36, 100])!;
      expect(m.type, MidiMessageType.noteOn);
      expect(m.channel, 10);
      expect(m.number, 36);
      expect(m.value, 100);
    });

    test('note on with velocity 0 is a note off', () {
      expect(MidiMessage.parse([0x90, 36, 0])!.type, MidiMessageType.noteOff);
    });

    test('control change', () {
      final m = MidiMessage.parse([0xB0, 70, 127])!;
      expect(m.type, MidiMessageType.controlChange);
      expect(m.describe(), 'CC 70 · ch 1 · 127');
    });

    test('ignores clock, short and unused messages', () {
      expect(MidiMessage.parse([0xF8]), isNull);
      expect(MidiMessage.parse([0xE0, 0, 64]), isNull); // pitch bend
    });
  });

  group('KnobBinding.scale', () {
    const pitch = KnobBinding(cc: 2, action: KnobAction.pitchCoarse, min: -16, max: 16);
    const vol = KnobBinding(cc: 1, action: KnobAction.channelVolume, min: 0, max: 1);

    test('centre 64 is exactly zero for ranges that span zero', () {
      expect(pitch.scale(64), 0);
      expect(pitch.scale(0), -16);
      expect(pitch.scale(127), 16);
    });

    test('ranges that do not span zero are linear', () {
      expect(vol.scale(0), 0);
      expect(vol.scale(127), 1);
      expect(vol.scale(64), closeTo(0.504, 0.001));
    });

    test('crossfader: full left = A, centre 64 = exactly middle, full right = B', () {
      const xf = KnobBinding(cc: 8, action: KnobAction.crossfader, min: 0, max: 1);
      expect(xf.scale(0), 0);
      expect(xf.scale(64), 0.5);
      expect(xf.scale(127), 1);
      expect(xf.scale(32), 0.25);
    });
  });

  group('MidiProfile YAML', () {
    final profile = MidiProfile.fromYaml(_profileYaml);

    test('parses knobs, pads and defaults', () {
      expect(profile.knobs, hasLength(5));
      expect(profile.pads, hasLength(3));
      expect(profile.knobs[1].min, 0);
      expect(profile.knobs[1].max, 1);
      expect(profile.knobs[2].takeover, Takeover.pickup);
      expect(profile.pads[1].holdMs, 1000);
    });

    test('JSON is accepted too, because JSON is valid YAML', () {
      final p = MidiProfile.fromYaml(
          '{"name": "J", "knobs": [{"cc": 7, "action": "masterVolume"}]}');
      expect(p.knobs.single.cc, 7);
    });

    test('device selection by name, with fallback', () {
      const fallback = MidiProfile(name: 'Generic');
      expect(MidiProfile.select('MPK Mini Mk II', [profile], fallback: fallback).name, 'Test');
      expect(MidiProfile.select('Something else', [profile], fallback: fallback).name, 'Generic');
    });

    test('errors name the bad entry', () {
      expect(
        () => MidiProfile.fromYaml('name: X\nknobs:\n  - { cc: 1, action: fly }'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('knobs[0]'))),
      );
      expect(() => MidiProfile.fromYaml('name: X\nknobs:\n  - { cc: 1, action: channelVolume }'),
          throwsFormatException); // missing deck
      expect(() => MidiProfile.fromYaml('name: X\npads:\n  - { note: 1, cc: 2, deck: A, on_press: stop }'),
          throwsFormatException); // both note and cc
      expect(() => MidiProfile.fromYaml('name: X\nknobs:\n  - { cc: 300, action: masterVolume }'),
          throwsFormatException);
    });
  });

  group('MidiMapper', () {
    late FakeTimers timers;
    late List<MixerCommand> out;
    late MidiMapper mapper;

    setUp(() {
      timers = FakeTimers();
      out = [];
      mapper = MidiMapper(MidiProfile.fromYaml(_profileYaml), emit: out.add, timer: timers.create);
    });

    test('knobs emit scaled value commands', () {
      mapper.handleBytes([0xB0, 1, 127]);
      mapper.handleBytes([0xB0, 2, 0]);
      mapper.handleBytes([0xB0, 3, 127]);
      expect(out[0], isA<SetChannelVolume>().having((c) => c.value, 'v', 1.0));
      expect(out[1], isA<SetPitchCoarse>().having((c) => c.value, 'v', -16.0)
          .having((c) => c.pickupTolerance, 'pickup', closeTo(0.96, 1e-9)));
      expect(out[2], isA<SetPitchFine>().having((c) => c.value, 'v', 1.0)
          .having((c) => c.pickupTolerance, 'pickup', isNull));
    });

    test('channel filter is respected', () {
      mapper.handleBytes([0xB0, 20, 64]);
      expect(out, isEmpty);
      mapper.handleBytes([0xB1, 20, 64]);
      expect(out.single, isA<SetCrossfader>());
    });

    test('pad press triggers on_press; release does nothing extra', () {
      mapper.handleBytes([0x90, 44, 100]);
      mapper.handleBytes([0x80, 44, 0]);
      expect(out.single, isA<TogglePlay>().having((c) => c.deckId, 'deck', 'A'));
    });

    test('pad tapped under 1 s: arm, then play from cue on release', () {
      mapper.handleBytes([0x90, 45, 100]);
      timers.advance(const Duration(milliseconds: 300));
      mapper.handleBytes([0x80, 45, 0]);
      timers.advance(const Duration(seconds: 2));
      expect(out.map((c) => c.runtimeType), [ArmCue, PlayFromCue]);
    });

    test('pad held 1 s: arm, then commit the cue; release adds nothing', () {
      mapper.handleBytes([0x90, 45, 100]);
      timers.advance(const Duration(milliseconds: 999));
      expect(out.map((c) => c.runtimeType), [ArmCue]);
      timers.advance(const Duration(milliseconds: 1));
      expect(out.map((c) => c.runtimeType), [ArmCue, CommitArmedCue]);
      mapper.handleBytes([0x90, 45, 0]); // note-on velocity 0 = release
      expect(out.map((c) => c.runtimeType), [ArmCue, CommitArmedCue]);
    });

    test('CC pads: press at >= 64, release below', () {
      mapper.handleBytes([0xB0, 50, 127]);
      mapper.handleBytes([0xB0, 50, 0]);
      expect(out.single, isA<Stop>().having((c) => c.deckId, 'deck', 'B'));
    });
  });

  group('SoftTakeover', () {
    test('ignores the knob until it reaches the current value', () {
      final t = SoftTakeover();
      expect(t.accept('k', -10, 4, 0.96), isFalse); // far below
      expect(t.accept('k', -2, 4, 0.96), isFalse);  // still below
      expect(t.accept('k', 6, 4, 0.96), isTrue);    // crossed 4
      expect(t.accept('k', 8, 6, 0.96), isTrue);    // engaged now
    });

    test('engages immediately when already close', () {
      expect(SoftTakeover().accept('k', 4.5, 4, 0.96), isTrue);
    });

    test('disengages when something else moves the value', () {
      final t = SoftTakeover();
      expect(t.accept('k', 4, 4, 0.96), isTrue);
      // on-screen fader moved the value to 10
      expect(t.accept('k', 5, 10, 0.96), isFalse);
    });
  });
}
