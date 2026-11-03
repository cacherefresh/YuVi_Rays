/// Silent no-op audio bridge used on native (macOS/Windows) builds, where
/// there is no browser/Tone.js runtime for `js_bridge_web.dart` to talk to.
/// Mirrors [YuViDVSJS]'s method surface exactly so callers don't need
/// platform checks. Replaced by a real native engine in a future session
/// (see packages/yuvi_vst_engine).
class YuViDVSJS {
  void setDartCallback(void Function(String jsonStr) callback) {}
  void initDeck(String deckId) {}
  void loadUrl(String deckId, String url) {}
  void play(String deckId) {}
  void pause(String deckId) {}
  void stop(String deckId) {}
  void seek(String deckId, double normalizedPosition) {}
  void setCuePoint(String deckId) {}
  void jumpToCue(String deckId) {}
  void setVolume(String deckId, double normalized) {}
  void setEQ(String deckId, String band, double value) {}
  void setPitch(String deckId, double semitones) {}
  double getPosition(String deckId) => 0.0;
  double getMasterLevel() => -100.0;

  void initAux() {}
  Future<String> listAudioInputsAsync() async => '[]';
  Future<void> selectAuxInputAsync(String deviceId) async {}
  void setAuxGain(double normalized) {}
  void setAuxVolume(double normalized) {}
  double getAuxLevel() => -100.0;
}

final yuViDVS = YuViDVSJS();
