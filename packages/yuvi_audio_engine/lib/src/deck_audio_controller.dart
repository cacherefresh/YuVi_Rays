import 'package:flutter/foundation.dart';
import 'js_bridge.dart';
import 'models/deck_state.dart';

class DeckAudioController {
  final DeckState state;

  // Crossfader multiplier applied on top of the deck's own volume.
  // Managed by MixerProvider; kept here so setVolume always composes correctly.
  double _crossGain = 1.0;

  DeckAudioController(this.state) {
    yuViDVS.initDeck(state.id);
  }

  // Called by MixerProvider whenever the crossfader moves.
  void applyCrossfaderGain(double gain) {
    _crossGain = gain.clamp(0.0, 1.0);
    yuViDVS.setVolume(state.id, state.volume * _crossGain);
  }

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
      case 'cue':
        state.update(cuePoint: (data['cuePoint'] as num?)?.toDouble());
      case 'ended':
        state.update(isPlaying: false, position: 0.0);
      case 'error':
        debugPrint('[DeckAudioController ${state.id}] ${data['message']}');
    }
  }

  void loadUrl(String url, {String? trackName}) {
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

  void play() {
    if (!state.isLoaded) return;
    yuViDVS.play(state.id);
    state.update(isPlaying: true);
  }

  void pause() {
    if (!state.isPlaying) return;
    yuViDVS.pause(state.id);
    state.update(isPlaying: false);
  }

  void stop() {
    yuViDVS.stop(state.id);
    state.update(isPlaying: false, position: 0.0);
  }

  void seek(double normalizedPosition) {
    yuViDVS.seek(state.id, normalizedPosition.clamp(0.0, 1.0));
  }

  void setCuePoint() => yuViDVS.setCuePoint(state.id);

  void jumpToCue() => yuViDVS.jumpToCue(state.id);

  void setVolume(double normalized) {
    state.update(volume: normalized);
    // Always compose with the crossfader gain so the two controls stay in sync.
    yuViDVS.setVolume(state.id, normalized.clamp(0.0, 1.0) * _crossGain);
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

  void setPitch(double semitones) {
    state.update(pitch: semitones);
    yuViDVS.setPitch(state.id, semitones.clamp(-7.0, 7.0));
  }
}
