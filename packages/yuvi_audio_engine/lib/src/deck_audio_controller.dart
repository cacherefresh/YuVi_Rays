import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:yuvi_track_metadata/yuvi_track_metadata.dart';

import 'contracts/mixer_controls.dart';
import 'js_bridge.dart';
import 'models/deck_state.dart';

class DeckAudioController implements DeckControls {
  final DeckState state;

  /// Playhead (0..1) remembered by [armCue], waiting for [commitArmedCue].
  double? _armedCue;

  /// Object URL of the last track loaded from bytes, revoked on the next load.
  String? _blobUrl;

  @override
  String get id => state.id;
  @override
  bool get isPlaying => state.isPlaying;
  @override
  double get volume => state.volume;
  @override
  double get pitchCoarse => state.pitchCoarse;
  @override
  double get pitchFine => state.pitchFine;
  @override
  double get cuePoint => state.cuePoint;
  @override
  bool get headphoneCue => state.headphoneCue;

  DeckAudioController(this.state) {
    yuViDVS.initDeck(state.id);
  }

  /// Sets this deck's crossfader gain node (linear 0..1).
  /// The crossfader is a separate node after the channel fader, so the two
  /// controls never need to know about each other.
  void applyCrossfaderGain(double gain) {
    yuViDVS.setCrossfaderGain(state.id, gain.clamp(0.0, 1.0));
  }

  @override
  void setHeadphoneCue(bool on) {
    state.update(headphoneCue: on);
    yuViDVS.setHeadphoneCue(state.id, on);
  }

  @override
  void toggleHeadphoneCue() => setHeadphoneCue(!state.headphoneCue);

  /// Play if paused, pause if playing.
  @override
  void togglePlay() => state.isPlaying ? pause() : play();

  void handleEvent(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'loaded':
        state.update(
          isLoaded: true,
          duration: (data['duration'] as num?)?.toDouble(),
        );
      case 'waveform':
        final raw = data['points'] as List?;
        final points = raw?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
        state.update(waveformData: points);
      case 'position':
        state.update(position: (data['position'] as num?)?.toDouble());
      case 'bpm':
        state.setDetectedBpm((data['bpm'] as num?)?.toDouble());
      case 'cue':
        state.update(cuePoint: (data['cuePoint'] as num?)?.toDouble());
      case 'ended':
        state.update(isPlaying: false, position: 0.0);
      case 'error':
        debugPrint('[DeckAudioController ${state.id}] ${data['message']}');
    }
  }

  /// Loads a track from its file bytes (a picked file or a bundled asset).
  /// Reads the file's tag BPM, if any, before handing the audio to the
  /// engine, which then detects the BPM itself.
  void loadBytes(Uint8List bytes, {required String trackName}) {
    final tagBpm = Id3v2Tag.parse(bytes)?.bpm;
    final seratoCues = SeratoMarkers.readHotCues(bytes);
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    loadUrl(url, trackName: trackName);
    state.setBpm(detected: null, tag: tagBpm);
    state.setHotCues(seratoCues);
    final old = _blobUrl;
    _blobUrl = url;
    if (old != null) web.URL.revokeObjectURL(old);
  }

  void loadUrl(String url, {String? trackName}) {
    state.setBpm(detected: null, tag: null);
    state.setHotCues(const {});
    state.update(
      trackName: trackName ?? url.split('/').last,
      isLoaded: false,
      isPlaying: false,
      position: 0.0,
      cuePoint: 0.0,
      waveformData: const [],
    );
    yuViDVS.loadUrl(state.id, url);
  }

  @override
  void play() {
    if (!state.isLoaded) return;
    yuViDVS.play(state.id);
    state.update(isPlaying: true);
  }

  @override
  void pause() {
    if (!state.isPlaying) return;
    yuViDVS.pause(state.id);
    state.update(isPlaying: false);
  }

  @override
  void stop() {
    yuViDVS.stop(state.id);
    state.update(isPlaying: false, position: 0.0);
  }

  void seek(double normalizedPosition) {
    yuViDVS.seek(state.id, normalizedPosition.clamp(0.0, 1.0));
  }

  @override
  void setCuePoint() => yuViDVS.setCuePoint(state.id);

  @override
  void jumpToCue() => yuViDVS.jumpToCue(state.id);

  @override
  void setVolume(double normalized) {
    state.update(volume: normalized.clamp(0.0, 1.0));
    yuViDVS.setVolume(state.id, normalized.clamp(0.0, 1.0));
  }

  void setEQ(String band, double value) {
    yuViDVS.setEQ(state.id, band, value.clamp(-1.0, 1.0));
    switch (band) {
      case 'high':
        state.update(highEQ: value);
      case 'mid':
        state.update(midEQ: value);
      case 'low':
        state.update(lowEQ: value);
    }
  }

  @override
  void playFromCue() {
    if (!state.isLoaded) return;
    jumpToCue();
    play();
  }

  @override
  void armCue() {
    if (!state.isLoaded) return;
    _armedCue = yuViDVS.getPosition(state.id);
  }

  @override
  void commitArmedCue() {
    final at = _armedCue;
    _armedCue = null;
    if (at == null) return;
    yuViDVS.setCuePointAt(state.id, at);
  }

  @override
  void triggerHotCue(int index) {
    if (!state.isLoaded || state.duration <= 0) return;
    if (index < 0 || index >= DeckState.hotCueSlots) return;
    final cue = state.hotCues[index];
    if (cue == null) {
      final seconds = yuViDVS.getPosition(state.id) * state.duration;
      state.setHotCue(
        index,
        HotCue(
          position: Duration(microseconds: (seconds * 1e6).round()),
          colorRgb: DeckState.defaultHotCueColors[index],
        ),
      );
    } else {
      seek(cue.seconds / state.duration);
    }
  }

  @override
  void clearHotCue(int index) => state.setHotCue(index, null);

  @override
  void setPitchCoarse(double percent) {
    state.update(pitchCoarse: percent);
    yuViDVS.setPlaybackRate(state.id, state.playbackRate);
  }

  @override
  void setPitchFine(double percent) {
    state.update(pitchFine: percent);
    yuViDVS.setPlaybackRate(state.id, state.playbackRate);
  }
}
