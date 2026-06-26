import 'package:flutter/foundation.dart';

class DeckState extends ChangeNotifier {
  final String id;

  String? trackName;
  bool isLoaded = false;
  bool isPlaying = false;
  double volume = 0.8;
  double highEQ = 0.0;
  double midEQ = 0.0;
  double lowEQ = 0.0;
  double pitch = 0.0;
  double position = 0.0;
  double duration = 0.0;
  double cuePoint = 0.0;
  List<double> waveformData = const [];

  DeckState(this.id);

  void update({
    String? trackName,
    bool? isLoaded,
    bool? isPlaying,
    double? volume,
    double? highEQ,
    double? midEQ,
    double? lowEQ,
    double? pitch,
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
    if (pitch != null) {
      final clamped = pitch.clamp(-7.0, 7.0);
      if (clamped != this.pitch) {
        this.pitch = clamped;
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
