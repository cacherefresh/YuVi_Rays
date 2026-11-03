import '../midi_mapping.dart';
import '../midi_message.dart';

/// Factory-typical default map for the Akai MPK Mini (mk2/mk3), 8 pads +
/// 25-key keyboard + 8 knobs, standard "CC" preset (PGM 1 on mk3).
///
/// MPK Mini has no motorized/linear faders — its 8 assignable knobs (K1-K8,
/// CC 1-8 out of the box) fill the "fader" role for channel volume here,
/// per the "first faders = the channel faders" request. Pads default to
/// notes 36-43 on MIDI channel 10 (General MIDI drum channel), which is
/// Akai's out-of-box factory default.
///
/// This is a best-effort convenience preset, not a guarantee — MIDI-Learn
/// (see [MidiLearnController]) is the source of truth if your unit or
/// firmware differs. See DJ_INSTRUCTIONS.md.
const akaiMpkMiniPreset = <MidiMapping>[
  // Knobs 1-3 → channel volumes (first 3 = the 3 channel faders).
  MidiMapping(controlId: MidiControlIds.deckAVolume, type: MidiType.cc, number: 1, channel: 0),
  MidiMapping(controlId: MidiControlIds.deckBVolume, type: MidiType.cc, number: 2, channel: 0),
  MidiMapping(controlId: MidiControlIds.auxVolume, type: MidiType.cc, number: 3, channel: 0),
  // Knob 4 → AUX gain (spare).
  MidiMapping(controlId: MidiControlIds.auxGain, type: MidiType.cc, number: 4, channel: 0),

  // Pads 1-3 → Deck A transport, pads 4-6 → Deck B transport.
  MidiMapping(controlId: MidiControlIds.deckAPlay, type: MidiType.note, number: 36, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckACue, type: MidiType.note, number: 37, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckAStop, type: MidiType.note, number: 38, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBPlay, type: MidiType.note, number: 39, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBCue, type: MidiType.note, number: 40, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBStop, type: MidiType.note, number: 41, channel: 9),
  // Pads 7-8 free for future use (loop/hot-cue).
];
