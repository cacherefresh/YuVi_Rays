import 'package:yuvi_audio_engine/mixer_contracts.dart';

/// A deck that simulates a playhead in plain Dart, so input handling can be
/// tested on the VM without Web Audio. Call [advance] as test time passes.
class FakeDeck implements DeckControls {
  FakeDeck(this.id, {this.durationSeconds = 200});

  @override
  final String id;
  final double durationSeconds;

  /// Playhead in track seconds.
  double seconds = 0;
  double? _armed;
  final log = <String>[];

  @override
  bool isPlaying = false;
  @override
  double volume = 0.8;
  @override
  double pitchCoarse = 0;
  @override
  double pitchFine = 0;
  @override
  double cuePoint = 0;

  double get playbackRate => playbackRateForPercent(pitchCoarse + pitchFine);

  /// Moves the playhead by [wall] of real time, at the current speed.
  void advance(Duration wall) {
    if (!isPlaying) return;
    seconds = (seconds + wall.inMicroseconds / 1e6 * playbackRate)
        .clamp(0, durationSeconds)
        .toDouble();
  }

  double get _normalized => seconds / durationSeconds;

  @override
  void play() => isPlaying = true;
  @override
  void pause() => isPlaying = false;
  @override
  void togglePlay() {
    isPlaying = !isPlaying;
    log.add(isPlaying ? 'play' : 'pause');
  }

  @override
  void stop() {
    isPlaying = false;
    seconds = 0;
    log.add('stop');
  }

  @override
  void setCuePoint() => cuePoint = _normalized;
  @override
  void jumpToCue() => seconds = cuePoint * durationSeconds;
  @override
  void playFromCue() {
    jumpToCue();
    isPlaying = true;
    log.add('playFromCue');
  }

  @override
  void armCue() => _armed = _normalized;
  @override
  void commitArmedCue() {
    if (_armed == null) return;
    cuePoint = _armed!;
    _armed = null;
    log.add('commitCue');
  }

  /// Hot cue positions in track seconds, by slot.
  final hotCues = List<double?>.filled(4, null);

  @override
  void triggerHotCue(int index) {
    if (hotCues[index] == null) {
      hotCues[index] = seconds;
      log.add('setHotCue${index + 1}');
    } else {
      seconds = hotCues[index]!;
      log.add('jumpHotCue${index + 1}');
    }
  }

  @override
  void clearHotCue(int index) {
    hotCues[index] = null;
    log.add('clearHotCue${index + 1}');
  }

  @override
  void setVolume(double v) => volume = v;
  @override
  void setPitchCoarse(double p) => pitchCoarse = p;
  @override
  void setPitchFine(double p) => pitchFine = p;
}

class FakeMixer implements MixerControls {
  final decks = {'A': FakeDeck('A'), 'B': FakeDeck('B')};

  @override
  FakeDeck? deck(String deckId) => decks[deckId];

  @override
  double masterVolume = 1;
  @override
  double headphoneVolume = 1;
  @override
  double crossfader = 0.5;

  @override
  void setMasterVolume(double v) => masterVolume = v;
  @override
  void setHeadphoneVolume(double v) => headphoneVolume = v;
  @override
  void setCrossfader(double v) => crossfader = v;
}
