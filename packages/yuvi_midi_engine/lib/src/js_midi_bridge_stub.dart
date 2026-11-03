/// Silent no-op MIDI bridge used on native (macOS/Windows) builds, where
/// there is no Web MIDI API for `js_midi_bridge_web.dart` to talk to.
/// Native desktop MIDI I/O is tracked as future work alongside the native
/// VST engine (see packages/yuvi_vst_engine).
class YuViMIDIJS {
  void setDartCallback(void Function(String jsonStr) callback) {}
  void requestAccess() {}
  bool get isSupported => false;
}

final yuViMIDI = YuViMIDIJS();
