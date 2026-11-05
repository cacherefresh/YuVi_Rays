import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

class MixerProvider extends ChangeNotifier implements MixerControls {
  final DeckState stateA = DeckState('A');
  final DeckState stateB = DeckState('B');
  final MasterState master = MasterState();

  late final DeckAudioController deckA;
  late final DeckAudioController deckB;
  late final MasterAudioController masterAudio;

  /// Where the headphone mix plays (a second output device).
  late final WebAudioOutputs outputs;

  MixerProvider() {
    deckA = DeckAudioController(stateA);
    deckB = DeckAudioController(stateB);
    masterAudio = MasterAudioController(master, left: deckA, right: deckB);
    outputs = WebAudioOutputs();

    // Single global callback dispatches to the right deck controller
    yuViDVS.setDartCallback(
      ((JSAny? json) {
        if (json == null) return;
        _handleJsEvent((json as JSString).toDart);
      }).toJS,
    );
  }

  /// The deck controller for [deckId], or null if there is no such deck.
  @override
  DeckAudioController? deck(String deckId) => switch (deckId) {
        'A' => deckA,
        'B' => deckB,
        _ => null,
      };

  @override
  double get crossfader => master.crossfader;
  @override
  double get masterVolume => master.masterVolume;
  @override
  double get headphoneVolume => master.headphoneVolume;
  @override
  double get headphoneMix => master.headphoneMix;

  void _handleJsEvent(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final event = map['event'] as String? ?? '';
      final deckId = map['deckId'] as String? ?? '';
      final data = (map['data'] as Map<String, dynamic>?) ?? {};
      if (deckId.isEmpty) {
        outputs.handleEvent(event, data); // mixer-wide events
      } else {
        deck(deckId)?.handleEvent(event, data);
      }
    } catch (e) {
      debugPrint('[MixerProvider] event parse error: $e');
    }
  }

  @override
  void setCrossfader(double value) {
    masterAudio.setCrossfader(value);
    notifyListeners();
  }

  /// Applies the "prefer tag BPM" setting to every deck.
  void setPreferTagBpm(bool value) {
    for (final s in [stateA, stateB]) {
      s.setPreferTagBpm(value);
    }
  }

  @override
  void setMasterVolume(double value) => masterAudio.setMasterVolume(value);

  @override
  void setHeadphoneVolume(double value) => masterAudio.setHeadphoneVolume(value);

  @override
  void setHeadphoneMix(double value) => masterAudio.setHeadphoneMix(value);
}
