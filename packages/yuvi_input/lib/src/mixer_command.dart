/// The contract between input sources (keyboard, MIDI, on-screen UI) and
/// whatever applies them to the mixer.
///
/// Input sources only ever produce these. They never touch audio.
/// Deck ids are strings so 3 or 4 decks work without changing the contract.
sealed class MixerCommand {
  const MixerCommand();
}

/// A command aimed at one deck.
sealed class DeckCommand extends MixerCommand {
  const DeckCommand(this.deckId);
  final String deckId;
}

/// A command that sets a continuous value from a knob, fader or slider.
///
/// When [pickupTolerance] is set, the value should only be applied once the
/// hardware control has "picked up" the current value (soft takeover). The
/// tolerance is in the same units as [value]. Null means apply immediately.
/// Implemented alongside [MixerCommand] by the value commands below.
abstract interface class ValueCommand {
  double get value;
  double? get pickupTolerance;
}

// ── Deck transport ────────────────────────────────────────────────────

final class TogglePlay extends DeckCommand {
  const TogglePlay(super.deckId);
  @override
  String toString() => 'TogglePlay($deckId)';
}

final class Stop extends DeckCommand {
  const Stop(super.deckId);
  @override
  String toString() => 'Stop($deckId)';
}

final class JumpToCue extends DeckCommand {
  const JumpToCue(super.deckId);
  @override
  String toString() => 'JumpToCue($deckId)';
}

/// Sets the cue at the current playhead.
final class SetCue extends DeckCommand {
  const SetCue(super.deckId);
  @override
  String toString() => 'SetCue($deckId)';
}

/// Jumps to the cue point and plays.
final class PlayFromCue extends DeckCommand {
  const PlayFromCue(super.deckId);
  @override
  String toString() => 'PlayFromCue($deckId)';
}

/// Remembers the current playhead as a pending cue (start of a pad hold).
final class ArmCue extends DeckCommand {
  const ArmCue(super.deckId);
  @override
  String toString() => 'ArmCue($deckId)';
}

/// Makes the pending cue from [ArmCue] the cue point (pad held long enough).
final class CommitArmedCue extends DeckCommand {
  const CommitArmedCue(super.deckId);
  @override
  String toString() => 'CommitArmedCue($deckId)';
}

/// Hot cue [index] (0-3): set it at the playhead when empty, else jump to it.
final class TriggerHotCue extends DeckCommand {
  const TriggerHotCue(super.deckId, this.index);
  final int index;
  @override
  String toString() => 'TriggerHotCue($deckId, ${index + 1})';
}

/// Empties hot cue [index] (0-3).
final class ClearHotCue extends DeckCommand {
  const ClearHotCue(super.deckId, this.index);
  final int index;
  @override
  String toString() => 'ClearHotCue($deckId, ${index + 1})';
}

// ── Continuous values ─────────────────────────────────────────────────

/// Channel volume, 0..1.
final class SetChannelVolume extends DeckCommand implements ValueCommand {
  const SetChannelVolume(super.deckId, this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetChannelVolume($deckId, $value)';
}

/// Coarse pitch, in percent of speed.
final class SetPitchCoarse extends DeckCommand implements ValueCommand {
  const SetPitchCoarse(super.deckId, this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetPitchCoarse($deckId, $value%)';
}

/// Fine pitch, in percent of speed, added to the coarse pitch.
final class SetPitchFine extends DeckCommand implements ValueCommand {
  const SetPitchFine(super.deckId, this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetPitchFine($deckId, $value%)';
}

/// Master volume, 0..1.
final class SetMasterVolume extends MixerCommand implements ValueCommand {
  const SetMasterVolume(this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetMasterVolume($value)';
}

/// Headphone volume, 0..1.
final class SetHeadphoneVolume extends MixerCommand implements ValueCommand {
  const SetHeadphoneVolume(this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetHeadphoneVolume($value)';
}

/// Crossfader, 0 (Deck A) .. 1 (Deck B).
final class SetCrossfader extends MixerCommand implements ValueCommand {
  const SetCrossfader(this.value, {this.pickupTolerance});
  @override
  final double value;
  @override
  final double? pickupTolerance;
  @override
  String toString() => 'SetCrossfader($value)';
}
