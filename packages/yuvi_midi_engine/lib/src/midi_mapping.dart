import 'midi_message.dart';

/// Binds one logical app control (identified by [controlId]) to a physical
/// MIDI CC number or note number.
class MidiMapping {
  const MidiMapping({
    required this.controlId,
    required this.type,
    required this.number,
    this.channel,
  });

  final String controlId;
  final MidiType type;
  final int number;

  /// Null = accept on any channel (most controllers ship on channel 0).
  final int? channel;

  bool matches(MidiMessage msg) {
    if (msg.type != type || msg.number != number) return false;
    if (channel != null && msg.channel != channel) return false;
    return true;
  }
}

/// Well-known control identifiers every widget/provider registers against.
class MidiControlIds {
  const MidiControlIds._();

  static const deckAVolume = 'deckA.volume';
  static const deckAPlay = 'deckA.play';
  static const deckACue = 'deckA.cue';
  static const deckAStop = 'deckA.stop';

  static const deckBVolume = 'deckB.volume';
  static const deckBPlay = 'deckB.play';
  static const deckBCue = 'deckB.cue';
  static const deckBStop = 'deckB.stop';

  static const auxVolume = 'aux.volume';
  static const auxGain = 'aux.gain';

  static const crossfader = 'crossfader';

  static const all = <String>[
    deckAVolume, deckAPlay, deckACue, deckAStop,
    deckBVolume, deckBPlay, deckBCue, deckBStop,
    auxVolume, auxGain,
    crossfader,
  ];

  static String label(String controlId) => switch (controlId) {
        deckAVolume => 'Deck A — Volume',
        deckAPlay => 'Deck A — Play/Pause',
        deckACue => 'Deck A — Cue',
        deckAStop => 'Deck A — Stop',
        deckBVolume => 'Deck B — Volume',
        deckBPlay => 'Deck B — Play/Pause',
        deckBCue => 'Deck B — Cue',
        deckBStop => 'Deck B — Stop',
        auxVolume => 'AUX — Volume',
        auxGain => 'AUX — Gain',
        crossfader => 'Crossfader',
        _ => controlId,
      };
}
