import 'dart:js_interop';

@JS('YuViDVS')
external YuViDVSJS get yuViDVS;

extension type YuViDVSJS._(JSObject _) implements JSObject {
  external void setDartCallback(JSFunction fn);
  external void initMaster();
  external void initDeck(String deckId);
  external void loadUrl(String deckId, String url);
  external void play(String deckId);
  external void pause(String deckId);
  external void stop(String deckId);
  external void seek(String deckId, double normalizedPosition);
  external void setCuePoint(String deckId);
  external void jumpToCue(String deckId);
  external void setVolume(String deckId, double normalized);
  external void setCrossfaderGain(String deckId, double gain);
  external void setMasterVolume(double normalized);
  external void setHeadphoneVolume(double normalized);
  external void setEQ(String deckId, String band, double value);
  external void setPlaybackRate(String deckId, double rate);
  external void setCuePointAt(String deckId, double normalized);
  external double getPosition(String deckId);
  external double getMasterLevel();
}
