// Guards the audio graph wiring in web/js/yuvi_bridge.js (plan 007).
//
// The graph runs only in a browser, so CI can't play audio. These checks read
// the bridge source and fail if a change breaks the routing rules:
//   - the headphone cue is taken BEFORE the channel fader (pre-fader / PFL),
//   - the speakers come straight off the master, not through the headphones,
//   - the headphone mix goes to its own output (MediaStreamDestination).
// The live check (cue audio with the fader at 0) is in the plan's build log.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final js = File('web/js/yuvi_bridge.js').readAsStringSync();
  bool has(String pattern) => RegExp(pattern).hasMatch(js);

  test('each deck: EQ feeds both the fader and the cue gate (pre-fader cue)', () {
    expect(has(r'eq3\.connect\(vol\)'), isTrue, reason: 'EQ → channel fader');
    expect(has(r'eq3\.connect\(cueGate\)'), isTrue, reason: 'EQ → cue gate, before the fader');
    expect(has(r'(vol|xfade)\.connect\(cueGate\)'), isFalse,
        reason: 'the cue must not be taken after the fader or crossfader');
    expect(has(r'cueGate\.connect\(master\.cueBus\)'), isTrue);
  });

  test('cue gate starts closed', () {
    expect(has(r'const cueGate = new Tone\.Gain\(0\)'), isTrue);
  });

  test('speakers come straight off the master', () {
    expect(has(r'masterVol\.toDestination\(\)'), isTrue);
    expect(has(r'phonesVol\.toDestination\(\)'), isFalse,
        reason: 'the headphone level must not sit on the speaker output');
    expect(has(r'masterVol\.connect\(phonesVol\)'), isFalse,
        reason: 'master reaches the headphones only through the mix');
  });

  test('headphone mix: cue bus and master blend, then level, then own output', () {
    expect(has(r'cueBus\.connect\(mixCue\)'), isTrue);
    expect(has(r'masterVol\.connect\(mixMaster\)'), isTrue);
    expect(has(r'mixCue\.connect\(phonesVol\)'), isTrue);
    expect(has(r'mixMaster\.connect\(phonesVol\)'), isTrue);
    expect(has(r'createMediaStreamDestination\(\)'), isTrue);
    expect(has(r'phonesVol\.connect\(phonesOut\)'), isTrue);
  });

  test('the headphone element is routed with setSinkId', () {
    expect(has(r'\.setSinkId\(deviceId\)'), isTrue);
    expect(has(r"addEventListener\('devicechange'"), isTrue, reason: 'unplug / replug handling');
  });

  test('every bridge function the Dart side calls exists in the JS', () {
    final dart = File('packages/yuvi_audio_engine/lib/src/js_bridge.dart').readAsStringSync();
    final names = RegExp(r'external \S+(?:<[^>]+>)? (\w+)\(').allMatches(dart).map((m) => m[1]!);
    for (final n in names) {
      expect(has('\\b$n: (async )?function'), isTrue, reason: 'YuViDVS.$n is missing in yuvi_bridge.js');
    }
  });
}
