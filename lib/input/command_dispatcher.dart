import 'package:yuvi_audio_engine/mixer_contracts.dart';
import 'package:yuvi_input/yuvi_input.dart';

/// Applies [MixerCommand]s from any input source to the mixer.
///
/// This is the only place that knows both the input contract and the mixer
/// contract, so keyboard, MIDI and future sources all behave the same.
/// It depends only on pure-Dart contracts, so it runs in VM tests and CI.
class CommandDispatcher {
  CommandDispatcher(this.mixer);

  final MixerControls mixer;
  final _takeover = SoftTakeover();

  void call(MixerCommand command) {
    switch (command) {
      case DeckCommand(:final deckId):
        final deck = mixer.deck(deckId);
        if (deck == null) return;
        _deck(deck, command);
      case SetMasterVolume():
        if (_accept(command, mixer.masterVolume)) mixer.setMasterVolume(command.value);
      case SetHeadphoneVolume():
        if (_accept(command, mixer.headphoneVolume)) mixer.setHeadphoneVolume(command.value);
      case SetHeadphoneMix():
        if (_accept(command, mixer.headphoneMix)) mixer.setHeadphoneMix(command.value);
      case SetCrossfader():
        if (_accept(command, mixer.crossfader)) mixer.setCrossfader(command.value);
    }
  }

  void _deck(DeckControls deck, DeckCommand command) {
    switch (command) {
      case TogglePlay():
        deck.togglePlay();
      case Stop():
        deck.stop();
      case JumpToCue():
        deck.jumpToCue();
      case SetCue():
        deck.setCuePoint();
      case PlayFromCue():
        deck.playFromCue();
      case ToggleHeadphoneCue():
        deck.toggleHeadphoneCue();
      case ArmCue():
        deck.armCue();
      case CommitArmedCue():
        deck.commitArmedCue();
      case TriggerHotCue(:final index):
        deck.triggerHotCue(index);
      case ClearHotCue(:final index):
        deck.clearHotCue(index);
      case SetChannelVolume():
        if (_accept(command, deck.volume)) deck.setVolume(command.value);
      case SetPitchCoarse():
        if (_accept(command, deck.pitchCoarse)) deck.setPitchCoarse(command.value);
      case SetPitchFine():
        if (_accept(command, deck.pitchFine)) deck.setPitchFine(command.value);
    }
  }

  /// Soft takeover for commands that ask for it; others always apply.
  bool _accept(ValueCommand c, double current) {
    final tolerance = c.pickupTolerance;
    if (tolerance == null) return true;
    final deckId = switch (c) {
      DeckCommand(:final deckId) => deckId,
      _ => null,
    };
    final key = (c.runtimeType, deckId);
    return _takeover.accept(key, c.value, current, tolerance);
  }
}
