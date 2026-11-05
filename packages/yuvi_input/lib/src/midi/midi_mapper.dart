import 'dart:async';

import '../mixer_command.dart';
import 'midi_message.dart';
import 'midi_profile.dart';

/// Creates timers. Injected so tests can control time.
typedef TimerFactory = Timer Function(Duration duration, void Function() callback);

/// Turns one device's MIDI messages into [MixerCommand]s using a [MidiProfile].
///
/// Stateful: it tracks pad presses so a pad can mean one thing when tapped
/// and another when held. Use one mapper per connected device.
class MidiMapper {
  MidiMapper(this.profile, {required this.emit, TimerFactory? timer})
      : _timer = timer ?? Timer.new;

  final MidiProfile profile;
  final void Function(MixerCommand command) emit;
  final TimerFactory _timer;
  final _pads = <PadBinding, _PadState>{};

  void handleBytes(List<int> bytes) {
    final m = MidiMessage.parse(bytes);
    if (m != null) handle(m);
  }

  void handle(MidiMessage m) {
    for (final k in profile.knobs) {
      if (k.matches(m)) emit(_knobCommand(k, k.scale(m.value)));
    }
    for (final p in profile.pads) {
      final pressed = p.pressOrRelease(m);
      if (pressed == true) _press(p);
      if (pressed == false) _release(p);
    }
  }

  /// Cancels pending hold timers.
  void dispose() {
    for (final s in _pads.values) {
      s.timer?.cancel();
    }
    _pads.clear();
  }

  void _press(PadBinding p) {
    final state = _pads.putIfAbsent(p, _PadState.new);
    if (state.down) return; // repeated press without release
    state
      ..down = true
      ..held = false;
    if (p.onPress != null) emit(_padCommand(p.onPress!, p));
    if (p.onHold != null) {
      state.timer = _timer(Duration(milliseconds: p.holdMs), () {
        if (!state.down) return;
        state.held = true;
        emit(_padCommand(p.onHold!, p));
      });
    }
  }

  void _release(PadBinding p) {
    final state = _pads[p];
    if (state == null || !state.down) return;
    state
      ..down = false
      ..timer?.cancel()
      ..timer = null;
    if (!state.held && p.onTap != null) emit(_padCommand(p.onTap!, p));
  }

  static MixerCommand _knobCommand(KnobBinding k, double v) {
    final tol = k.takeover == Takeover.pickup ? k.pickupTolerance : null;
    final deck = k.deckId ?? '';
    return switch (k.action) {
      KnobAction.channelVolume => SetChannelVolume(deck, v, pickupTolerance: tol),
      KnobAction.masterVolume => SetMasterVolume(v, pickupTolerance: tol),
      KnobAction.headphoneVolume => SetHeadphoneVolume(v, pickupTolerance: tol),
      KnobAction.headphoneMix => SetHeadphoneMix(v, pickupTolerance: tol),
      KnobAction.crossfader => SetCrossfader(v, pickupTolerance: tol),
      KnobAction.pitchCoarse => SetPitchCoarse(deck, v, pickupTolerance: tol),
      KnobAction.pitchFine => SetPitchFine(deck, v, pickupTolerance: tol),
    };
  }

  static MixerCommand _padCommand(PadAction a, PadBinding p) {
    final deck = p.deckId;
    final index = (p.slot ?? 1) - 1;
    return switch (a) {
        PadAction.togglePlay => TogglePlay(deck),
        PadAction.stop => Stop(deck),
        PadAction.jumpToCue => JumpToCue(deck),
        PadAction.setCue => SetCue(deck),
        PadAction.playFromCue => PlayFromCue(deck),
        PadAction.armCue => ArmCue(deck),
        PadAction.commitCue => CommitArmedCue(deck),
        PadAction.headphoneCue => ToggleHeadphoneCue(deck),
        PadAction.hotCue => TriggerHotCue(deck, index),
        PadAction.clearHotCue => ClearHotCue(deck, index),
      };
  }
}

class _PadState {
  bool down = false;
  bool held = false;
  Timer? timer;
}
