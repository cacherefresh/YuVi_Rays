// `dart:ffi` (used by the real controller) cannot compile for web targets
// at all. On web, fall back to a no-op stub; on native (macOS/Windows)
// targets the real FFI-backed controller is used (which itself degrades
// to no-ops if native/yuvi_vst_host hasn't been built yet).
export 'vst_channel_controller_stub.dart' if (dart.library.ffi) 'vst_channel_controller_native.dart';
