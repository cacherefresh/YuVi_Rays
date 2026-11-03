import '../midi_mapping.dart';
import '../midi_message.dart';

/// Factory-typical default map for the Akai MPD218/MPD226, 16 pads (bank
/// A) + 3 assignable Q-Link knobs, factory program 1.
///
/// Neither the MPD218 nor the MPD226 has true motorized/linear faders —
/// their 3 Q-Link knobs (CC 1-3 out of the box) fill the "fader" role for
/// channel volume here, per the "first faders = the channel faders"
/// request. Pads default to notes 36-51 on MIDI channel 10 (bank A).
///
/// Best-effort convenience preset — MIDI-Learn is the source of truth if
/// your unit/firmware differs. See DJ_INSTRUCTIONS.md.
const akaiMpd218Preset = <MidiMapping>[
  // Q-Link knobs 1-3 → the 3 channel faders.
  MidiMapping(controlId: MidiControlIds.deckAVolume, type: MidiType.cc, number: 1, channel: 0),
  MidiMapping(controlId: MidiControlIds.deckBVolume, type: MidiType.cc, number: 2, channel: 0),
  MidiMapping(controlId: MidiControlIds.auxVolume, type: MidiType.cc, number: 3, channel: 0),

  // Pads 1-3 → Deck A transport, pads 4-6 → Deck B transport (bank A, notes 36-51).
  MidiMapping(controlId: MidiControlIds.deckAPlay, type: MidiType.note, number: 36, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckACue, type: MidiType.note, number: 37, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckAStop, type: MidiType.note, number: 38, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBPlay, type: MidiType.note, number: 39, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBCue, type: MidiType.note, number: 40, channel: 9),
  MidiMapping(controlId: MidiControlIds.deckBStop, type: MidiType.note, number: 41, channel: 9),
  // Remaining 10 pads (notes 42-51) free for future use (loop/hot-cue).
];
