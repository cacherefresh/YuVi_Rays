import 'dart:js_interop';

import 'package:yuvi_input/yuvi_input_web.dart';

/// Debug builds only: exposes `window.yuviDebugInjectMidi(deviceName, bytes)`
/// so the browser console or Chrome's debugger can drive the app with fake
/// MIDI, exactly as if a controller sent it. Not installed in release
/// builds, so it never ships to GitHub Pages.
///
/// Example, in the browser console:
///   yuviDebugInjectMidi('MPK Mini Mk II', [0x90, 44, 100])  // pad 1 down
void installDebugMidiHook(MidiInputSource midi) {
  _hook = ((JSString device, JSArray<JSNumber> bytes) {
    midi.inject(device.toDart, [for (final b in bytes.toDart) b.toDartInt]);
  }).toJS;
}

@JS('yuviDebugInjectMidi')
external set _hook(JSFunction f);
