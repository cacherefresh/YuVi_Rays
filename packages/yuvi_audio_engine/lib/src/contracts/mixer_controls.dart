/// The mixer contract that input handling talks to.
///
/// Pure Dart with no browser or audio dependency, so command handling can be
/// unit tested against a fake mixer on the Dart VM, including in CI.
/// The real implementations wrap the Web Audio bridge.
library;

/// One deck's controls and the state that input handling needs to read.
abstract interface class DeckControls {
  String get id;
  bool get isPlaying;

  /// Channel volume, 0..1.
  double get volume;

  /// Coarse and fine pitch, in percent of speed.
  double get pitchCoarse;
  double get pitchFine;

  /// Cue point as a fraction of the track, 0..1.
  double get cuePoint;

  void play();
  void pause();
  void togglePlay();
  void stop();

  /// Sets the cue point at the current playhead.
  void setCuePoint();
  void jumpToCue();

  /// Jumps to the cue point and plays.
  void playFromCue();

  /// Remembers the current playhead as a pending cue (start of a hold).
  void armCue();

  /// Makes the pending cue from [armCue] the cue point (hold completed).
  void commitArmedCue();

  /// Hot cue [index] (0-3): sets it at the playhead when empty, otherwise
  /// jumps to it. Playing or paused stays as it was.
  void triggerHotCue(int index);

  /// Empties hot cue [index] (0-3).
  void clearHotCue(int index);

  void setVolume(double normalized);
  void setPitchCoarse(double percent);
  void setPitchFine(double percent);

  /// Headphone cue (PFL): this deck's sound, taken after the EQ and before
  /// the channel fader, goes to the headphone mix.
  bool get headphoneCue;
  void setHeadphoneCue(bool on);
  void toggleHeadphoneCue();
}

/// The whole mixer: decks plus the master section.
abstract interface class MixerControls {
  /// The deck with [deckId], or null when there is none.
  DeckControls? deck(String deckId);

  double get masterVolume;
  /// Headphone level, 0..1. Affects only the headphones.
  double get headphoneVolume;

  /// Headphone cue/master mix: 0 = cued decks only, 0.5 = both,
  /// 1 = master only.
  double get headphoneMix;
  double get crossfader;

  void setMasterVolume(double normalized);
  void setHeadphoneVolume(double normalized);
  void setHeadphoneMix(double position);
  void setCrossfader(double position);
}
