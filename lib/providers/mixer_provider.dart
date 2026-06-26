import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

class MixerProvider extends ChangeNotifier {
  final DeckState stateA = DeckState('A');
  final DeckState stateB = DeckState('B');

  late final DeckAudioController deckA;
  late final DeckAudioController deckB;

  double crossfader = 0.5;

  MixerProvider() {
    deckA = DeckAudioController(stateA);
    deckB = DeckAudioController(stateB);

    // Single global callback dispatches to the right deck controller
    yuViDVS.setDartCallback(
      ((JSAny? json) {
        if (json == null) return;
        _handleJsEvent((json as JSString).toDart);
      }).toJS,
    );
  }

  void _handleJsEvent(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final event = map['event'] as String? ?? '';
      final deckId = map['deckId'] as String? ?? '';
      final data = (map['data'] as Map<String, dynamic>?) ?? {};
      switch (deckId) {
        case 'A':
          deckA.handleEvent(event, data);
        case 'B':
          deckB.handleEvent(event, data);
      }
    } catch (e) {
      debugPrint('[MixerProvider] event parse error: $e');
    }
  }

  void setCrossfader(double value) {
    crossfader = value.clamp(0.0, 1.0);
    // Equal-power crossfade curve.
    // Delegate through the controllers so their _crossGain is updated —
    // that way subsequent volume-fader moves also compose with this gain.
    final aGain = math.cos(crossfader * math.pi / 2);
    final bGain = math.cos((1.0 - crossfader) * math.pi / 2);
    deckA.applyCrossfaderGain(aGain);
    deckB.applyCrossfaderGain(bGain);
    notifyListeners();
  }
}
