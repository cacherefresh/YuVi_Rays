import 'dart:js_interop';

@JS('YuViMIDI')
external YuViMIDIJS get yuViMIDI;

extension type YuViMIDIJS._(JSObject _) implements JSObject {
  @JS('setDartCallback')
  external void _setDartCallbackJS(JSFunction fn);

  /// Plain-Dart callback registration — keeps `dart:js_interop` types
  /// contained inside this web-only file (see js_bridge_web.dart for the
  /// same pattern on the audio bridge).
  void setDartCallback(void Function(String jsonStr) callback) {
    _setDartCallbackJS(((JSAny? json) {
      if (json == null) return;
      callback((json as JSString).toDart);
    }).toJS);
  }

  external void requestAccess();
  external bool get isSupported;
}
