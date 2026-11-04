import 'package:web/web.dart' as web;
import 'package:yuvi_input/yuvi_input.dart';

/// Keeps MIDI mapping choices and imported custom profiles in the
/// browser's localStorage, so they survive reloads.
///
/// localStorage can throw in private windows or when site data is blocked;
/// mappings then just aren't remembered.
class LocalStorageMidiMappingStore implements MidiMappingStore {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String? value) {
    try {
      value == null
          ? web.window.localStorage.removeItem(key)
          : web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }
}
