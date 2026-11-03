// `dart:js_interop` (used by the real bridge) only compiles for web targets.
// On native (macOS/Windows) builds, fall back to a silent no-op bridge so
// the app still compiles and launches — the native audio engine that
// replaces this for desktop is tracked separately (see packages/yuvi_vst_engine).
export 'js_bridge_stub.dart' if (dart.library.js_interop) 'js_bridge_web.dart';
