// `dart:js_interop` (used by the real bridge) only compiles for web targets.
// On native (macOS/Windows) builds, fall back to an unsupported no-op bridge.
export 'js_midi_bridge_stub.dart' if (dart.library.js_interop) 'js_midi_bridge_web.dart';
