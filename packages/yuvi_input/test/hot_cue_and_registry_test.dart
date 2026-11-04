import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_input/yuvi_input.dart';

const _mk2 = '../../assets/midi_profiles/akai_mpk_mini_mk2.yaml';

void main() {
  group('hot cue keys', () {
    final b = KeyboardBindings.diagonalColumns();

    test('1-4 trigger deck A hot cues, 7-0 deck B', () {
      expect(b.lookup(PhysicalKeyboardKey.digit1),
          isA<TriggerHotCue>().having((c) => c.deckId, 'deck', 'A').having((c) => c.index, 'i', 0));
      expect(b.lookup(PhysicalKeyboardKey.digit4), isA<TriggerHotCue>().having((c) => c.index, 'i', 3));
      expect(b.lookup(PhysicalKeyboardKey.digit7),
          isA<TriggerHotCue>().having((c) => c.deckId, 'deck', 'B').having((c) => c.index, 'i', 0));
      expect(b.lookup(PhysicalKeyboardKey.digit0), isA<TriggerHotCue>().having((c) => c.index, 'i', 3));
    });

    test('Shift + number clears', () {
      expect(b.lookup(PhysicalKeyboardKey.digit2, shift: true),
          isA<ClearHotCue>().having((c) => c.index, 'i', 1));
    });

    test('5 and 6 stay free', () {
      expect(b.lookup(PhysicalKeyboardKey.digit5), isNull);
    });
  });

  group('hot cue pads', () {
    test('slot is required for hot cue actions', () {
      expect(() => MidiProfile.fromYaml('name: X\npads:\n  - { note: 1, deck: A, on_press: hotCue }'),
          throwsFormatException);
      expect(() => MidiProfile.fromYaml('name: X\npads:\n  - { note: 1, deck: A, slot: 5, on_press: hotCue }'),
          throwsFormatException);
    });

    test('MPK Mini Mk II bank B pads trigger hot cues', () {
      final out = <MixerCommand>[];
      final mapper = MidiMapper(MidiProfile.fromYaml(File(_mk2).readAsStringSync()), emit: out.add);
      mapper.handleBytes([0x90, 32, 100]); // bank B pad 1
      mapper.handleBytes([0x90, 39, 100]); // bank B pad 8
      expect(out[0], isA<TriggerHotCue>().having((c) => c.deckId, 'deck', 'A').having((c) => c.index, 'i', 0));
      expect(out[1], isA<TriggerHotCue>().having((c) => c.deckId, 'deck', 'B').having((c) => c.index, 'i', 3));
    });
  });

  group('YAML export', () {
    test('every bundled profile survives export and re-import', () {
      for (final f in Directory('../../assets/midi_profiles').listSync().whereType<File>()) {
        final original = MidiProfile.fromYaml(f.readAsStringSync());
        final again = MidiProfile.fromYaml(original.toYaml());
        expect(again.toYaml(), original.toYaml(), reason: f.path);
        expect(again.knobs.length, original.knobs.length);
        expect(again.pads.length, original.pads.length);
      }
    });

    test('names with quotes are escaped', () {
      const p = MidiProfile(name: "Rob's controller");
      expect(MidiProfile.fromYaml(p.toYaml()).name, "Rob's controller");
    });
  });

  group('MidiProfileRegistry', () {
    const mpk = MidiProfile(name: 'MPK', deviceNameContains: ['MPK']);
    const other = MidiProfile(name: 'Other', deviceNameContains: ['XYZ']);
    const generic = MidiProfile(name: 'Generic');
    late MidiProfileRegistry r;
    setUp(() => r = MidiProfileRegistry(bundled: [mpk, other], fallback: generic));

    test('automatic: matched by device name, else fallback', () {
      expect(r.resolve('MPK Mini Mk II').name, 'MPK');
      expect(r.resolve('Unknown pad').name, 'Generic');
    });

    test('a chosen bundled profile wins over the name match', () {
      r.choose('MPK Mini Mk II', 'Other');
      expect(r.resolve('MPK Mini Mk II').name, 'Other');
      r.choose('MPK Mini Mk II', MidiProfileRegistry.automatic);
      expect(r.resolve('MPK Mini Mk II').name, 'MPK');
    });

    test('an imported custom profile wins, and reset forgets it', () {
      r.importCustom('Unknown pad', 'name: Mine\nknobs:\n  - { cc: 9, action: masterVolume }');
      expect(r.resolve('Unknown pad').name, 'Mine');
      expect(r.choiceFor('Unknown pad'), MidiProfileRegistry.custom);
      r.reset('Unknown pad');
      expect(r.resolve('Unknown pad').name, 'Generic');
    });

    test('invalid custom YAML is rejected and nothing is stored', () {
      expect(() => r.importCustom('X', 'name: Bad\nknobs:\n  - { cc: 1, action: fly }'), throwsFormatException);
      expect(r.choiceFor('X'), MidiProfileRegistry.automatic);
    });

    test('choices are kept per device, in the store', () {
      final store = InMemoryMidiMappingStore();
      MidiProfileRegistry(bundled: [mpk, other], fallback: generic, store: store).choose('A', 'Other');
      final again = MidiProfileRegistry(bundled: [mpk, other], fallback: generic, store: store);
      expect(again.resolve('A').name, 'Other');
      expect(again.resolve('B').name, 'Generic');
    });
  });
}
