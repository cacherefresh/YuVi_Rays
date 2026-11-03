import 'crossfader_curve.dart';
import 'deck_audio_controller.dart';
import 'js_bridge.dart';
import 'models/master_state.dart';

/// Controls the master section of the audio graph: master volume,
/// headphone volume and the crossfader between two decks.
///
/// The crossfader is assigned to a [left] and [right] deck so a 3rd or 4th
/// deck can stay off the crossfader (straight to master).
class MasterAudioController {
  MasterAudioController(
    this.state, {
    required this.left,
    required this.right,
  }) {
    yuViDVS.initMaster();
    setMasterVolume(state.masterVolume);
    setHeadphoneVolume(state.headphoneVolume);
    setCrossfader(state.crossfader);
  }

  final MasterState state;
  final DeckAudioController left;
  final DeckAudioController right;

  void setMasterVolume(double normalized) {
    final v = normalized.clamp(0.0, 1.0);
    state.update(masterVolume: v);
    yuViDVS.setMasterVolume(v);
  }

  void setHeadphoneVolume(double normalized) {
    final v = normalized.clamp(0.0, 1.0);
    state.update(headphoneVolume: v);
    yuViDVS.setHeadphoneVolume(v);
  }

  void setCrossfader(double position) {
    final x = position.clamp(0.0, 1.0);
    state.update(crossfader: x);
    final gains = equalPowerCrossfade(x);
    left.applyCrossfaderGain(gains.left);
    right.applyCrossfaderGain(gains.right);
  }
}
