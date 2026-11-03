import 'package:flutter/foundation.dart';

import 'package:yuvi_track_metadata/yuvi_track_metadata.dart';

import '../pitch_math.dart';

class DeckState extends ChangeNotifier {
  final String id;

  String? trackName;
  bool isLoaded = false;
  bool isPlaying = false;
  double volume = 0.8;
  double highEQ = 0.0;
  double midEQ = 0.0;
  double lowEQ = 0.0;
  /// Coarse pitch, percent of speed (e.g. the pitch fader or a big knob).
  double pitchCoarse = 0.0;

  /// Fine pitch, percent of speed, added on top of [pitchCoarse].
  double pitchFine = 0.0;
  double position = 0.0;
  double duration = 0.0;
  double cuePoint = 0.0;
  List<double> waveformData = const [];

  DeckState(this.id);

  /// Number of hot cue slots per deck.
  static const hotCueSlots = 4;

  /// Default hot cue colours by slot (Serato's first four), as 0xRRGGBB.
  static const defaultHotCueColors = [0xCC0000, 0xCC8800, 0x0000CC, 0xCCCC00];

  /// Hot cues by slot; null = empty. Read from the file's Serato tag on
  /// load, or set while playing. Not saved yet (plan 005).
  List<HotCue?> hotCues = List.filled(hotCueSlots, null);

  /// Replaces all hot cues. Slots beyond [hotCueSlots] are ignored.
  void setHotCues(Map<int, HotCue> bySlot) {
    hotCues = [for (var i = 0; i < hotCueSlots; i++) bySlot[i]];
    notifyListeners();
  }

  void setHotCue(int index, HotCue? cue) {
    if (index < 0 || index >= hotCueSlots || hotCues[index] == cue) return;
    hotCues = [...hotCues]..[index] = cue;
    notifyListeners();
  }

  /// Tempo found by the beat detector when the track loaded, or null.
  double? detectedBpm;

  /// Tempo from the file's tag (ID3 TBPM), or null.
  double? tagBpm;

  /// Prefer [tagBpm] over [detectedBpm] when both exist.
  bool preferTagBpm = false;

  /// The track's own tempo, from the preferred source, falling back to the
  /// other one when the preferred source has none.
  double? get baseBpm =>
      preferTagBpm ? (tagBpm ?? detectedBpm) : (detectedBpm ?? tagBpm);

  /// Tempo as it plays now: [baseBpm] × the pitch speed change.
  double? get currentBpm {
    final b = baseBpm;
    return b == null ? null : b * playbackRate;
  }

  /// Sets both BPM values at once (null clears). Notifies on change.
  void setBpm({required double? detected, required double? tag}) {
    if (detected == detectedBpm && tag == tagBpm) return;
    detectedBpm = detected;
    tagBpm = tag;
    notifyListeners();
  }

  void setDetectedBpm(double? bpm) => setBpm(detected: bpm, tag: tagBpm);

  void setPreferTagBpm(bool value) {
    if (value == preferTagBpm) return;
    preferTagBpm = value;
    notifyListeners();
  }

  /// Total speed change in percent: coarse + fine.
  double get pitchPercent => pitchCoarse + pitchFine;

  /// Playback-rate multiplier, e.g. 1.04 for +4%.
  double get playbackRate => playbackRateForPercent(pitchPercent);

  /// Key change in semitones at the current speed (no key lock).
  double get pitchSemitones => semitonesForPercent(pitchPercent);

  void update({
    String? trackName,
    bool? isLoaded,
    bool? isPlaying,
    double? volume,
    double? highEQ,
    double? midEQ,
    double? lowEQ,
    double? pitchCoarse,
    double? pitchFine,
    double? position,
    double? duration,
    double? cuePoint,
    List<double>? waveformData,
  }) {
    var changed = false;
    void set<T>(T? val, T current, void Function(T) assign) {
      if (val != null && val != current) {
        assign(val);
        changed = true;
      }
    }

    if (trackName != null && trackName != this.trackName) {
      this.trackName = trackName;
      changed = true;
    }
    set(isLoaded, this.isLoaded, (v) => this.isLoaded = v);
    set(isPlaying, this.isPlaying, (v) => this.isPlaying = v);
    if (volume != null) {
      final clamped = volume.clamp(0.0, 1.0);
      if (clamped != this.volume) {
        this.volume = clamped;
        changed = true;
      }
    }
    if (highEQ != null) {
      final clamped = highEQ.clamp(-1.0, 1.0);
      if (clamped != this.highEQ) {
        this.highEQ = clamped;
        changed = true;
      }
    }
    if (midEQ != null) {
      final clamped = midEQ.clamp(-1.0, 1.0);
      if (clamped != this.midEQ) {
        this.midEQ = clamped;
        changed = true;
      }
    }
    if (lowEQ != null) {
      final clamped = lowEQ.clamp(-1.0, 1.0);
      if (clamped != this.lowEQ) {
        this.lowEQ = clamped;
        changed = true;
      }
    }
    if (pitchCoarse != null) {
      final clamped = pitchCoarse.clamp(-50.0, 50.0);
      if (clamped != this.pitchCoarse) {
        this.pitchCoarse = clamped;
        changed = true;
      }
    }
    if (pitchFine != null) {
      final clamped = pitchFine.clamp(-10.0, 10.0);
      if (clamped != this.pitchFine) {
        this.pitchFine = clamped;
        changed = true;
      }
    }
    if (position != null) {
      this.position = position.clamp(0.0, 1.0);
      changed = true;
    }
    set(duration, this.duration, (v) => this.duration = v);
    if (cuePoint != null) {
      final clamped = cuePoint.clamp(0.0, 1.0);
      if (clamped != this.cuePoint) {
        this.cuePoint = clamped;
        changed = true;
      }
    }
    if (waveformData != null) {
      this.waveformData = waveformData;
      changed = true;
    }

    if (changed) notifyListeners();
  }
}
