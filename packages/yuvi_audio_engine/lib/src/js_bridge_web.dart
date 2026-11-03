import 'dart:js_interop';

@JS('YuViDVS')
external YuViDVSJS get yuViDVS;

extension type YuViDVSJS._(JSObject _) implements JSObject {
  @JS('setDartCallback')
  external void _setDartCallbackJS(JSFunction fn);

  /// Plain-Dart callback registration — keeps `dart:js_interop` types
  /// (JSAny/JSFunction/.toJS) contained inside this web-only file so
  /// callers (e.g. MixerProvider) stay platform-agnostic.
  void setDartCallback(void Function(String jsonStr) callback) {
    _setDartCallbackJS(((JSAny? json) {
      if (json == null) return;
      callback((json as JSString).toDart);
    }).toJS);
  }

  external void initDeck(String deckId);
  external void loadUrl(String deckId, String url);
  external void play(String deckId);
  external void pause(String deckId);
  external void stop(String deckId);
  external void seek(String deckId, double normalizedPosition);
  external void setCuePoint(String deckId);
  external void jumpToCue(String deckId);
  external void setVolume(String deckId, double normalized);
  external void setEQ(String deckId, String band, double value);
  external void setPitch(String deckId, double semitones);
  external double getPosition(String deckId);
  external double getMasterLevel();

  // ── AUX / virtual-audio-input channel ──────────────────────────────
  external void initAux();

  @JS('listAudioInputs')
  external JSPromise<JSString> _listAudioInputsJS();

  @JS('selectAuxInput')
  external JSPromise<JSAny?> _selectAuxInputJS(String deviceId);

  external void setAuxGain(double normalized);
  external void setAuxVolume(double normalized);
  external double getAuxLevel();

  /// JSON-encoded array of `{id, label}` input devices — normalized to a
  /// plain Dart [Future] so callers don't touch JS interop types directly
  /// (and so [js_bridge_stub.dart] can mirror the same signature).
  Future<String> listAudioInputsAsync() async =>
      (await _listAudioInputsJS().toDart).toDart;

  Future<void> selectAuxInputAsync(String deviceId) async {
    await _selectAuxInputJS(deviceId).toDart;
  }
}
