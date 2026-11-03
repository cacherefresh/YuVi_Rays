import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'js_midi_bridge.dart';
import 'midi_mapping.dart';
import 'midi_message.dart';

/// Generic MIDI-Learn engine: every mappable app control registers a
/// callback once at startup; incoming MIDI messages are matched against
/// the current mapping table and dispatched to the right callback.
///
/// This is the single source of truth for hardware control — the Akai
/// default presets (see default_maps/) are just a convenience starting
/// point applied through the same [applyPreset] path a user's own Learn
/// session would use.
class MidiLearnController extends ChangeNotifier {
  final Map<String, MidiMapping> _mappings = {};
  final Map<String, ValueChanged<double>> _dispatch = {};

  String? _learningControlId;

  bool get isSupported => yuViMIDI.isSupported;
  String? get learningControlId => _learningControlId;
  Map<String, MidiMapping> get mappings => Map.unmodifiable(_mappings);

  MidiLearnController() {
    yuViMIDI.setDartCallback(_handleJsEvent);
    yuViMIDI.requestAccess();
  }

  /// Called once per control at app startup (deck volumes, transport
  /// buttons, AUX gain/volume, crossfader, …).
  void registerControl(String controlId, ValueChanged<double> callback) {
    _dispatch[controlId] = callback;
  }

  void startLearn(String controlId) {
    _learningControlId = controlId;
    notifyListeners();
  }

  void cancelLearn() {
    _learningControlId = null;
    notifyListeners();
  }

  void clearMapping(String controlId) {
    _mappings.remove(controlId);
    notifyListeners();
  }

  void applyPreset(List<MidiMapping> preset) {
    for (final mapping in preset) {
      _mappings[mapping.controlId] = mapping;
    }
    notifyListeners();
  }

  void _handleJsEvent(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      handleIncoming(MidiMessage.fromJson(map));
    } catch (e) {
      debugPrint('[MidiLearnController] event parse error: $e');
    }
  }

  /// Exposed directly for tests / non-JS-sourced messages.
  void handleIncoming(MidiMessage msg) {
    if (_learningControlId != null) {
      _mappings[_learningControlId!] = MidiMapping(
        controlId: _learningControlId!,
        type: msg.type,
        number: msg.number,
        channel: msg.channel,
      );
      _learningControlId = null;
      notifyListeners();
      return;
    }

    for (final mapping in _mappings.values) {
      if (mapping.matches(msg)) {
        _dispatch[mapping.controlId]?.call(msg.normalized);
        return;
      }
    }
  }
}
