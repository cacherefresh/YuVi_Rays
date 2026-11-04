import 'package:flutter/services.dart';

import '../mixer_command.dart';

/// Maps physical keys (plus Shift) to mixer commands.
///
/// Physical keys are used so the layout depends on key *position*:
/// `[` and `{` are the same key, and non-US layouts keep the column shape.
class KeyboardBindings {
  const KeyboardBindings(this._bindings);

  final Map<({PhysicalKeyboardKey key, bool shift}), MixerCommand> _bindings;

  /// Two decks, each controlled by a diagonal column of keys:
  ///
  /// ```
  ///   [ ]   play / pause
  ///    ; '  jump to cue   (Shift = set cue)
  ///     . / stop
  ///
  ///   1 2 3 4   hot cues, left deck     7 8 9 0   hot cues, right deck
  ///   (Shift + number clears the hot cue)
  /// ```
  factory KeyboardBindings.diagonalColumns({
    String left = 'A',
    String right = 'B',
  }) {
    return KeyboardBindings({
      (key: PhysicalKeyboardKey.bracketLeft, shift: false): TogglePlay(left),
      (key: PhysicalKeyboardKey.semicolon, shift: false): JumpToCue(left),
      (key: PhysicalKeyboardKey.semicolon, shift: true): SetCue(left),
      (key: PhysicalKeyboardKey.period, shift: false): Stop(left),
      (key: PhysicalKeyboardKey.bracketRight, shift: false): TogglePlay(right),
      (key: PhysicalKeyboardKey.quote, shift: false): JumpToCue(right),
      (key: PhysicalKeyboardKey.quote, shift: true): SetCue(right),
      (key: PhysicalKeyboardKey.slash, shift: false): Stop(right),
      // Hot cues: 1-4 for the left deck, 7-0 for the right deck.
      // Shift + the key clears that hot cue.
      for (final (i, k) in _leftHotCueKeys.indexed) ...{
        (key: k, shift: false): TriggerHotCue(left, i),
        (key: k, shift: true): ClearHotCue(left, i),
      },
      for (final (i, k) in _rightHotCueKeys.indexed) ...{
        (key: k, shift: false): TriggerHotCue(right, i),
        (key: k, shift: true): ClearHotCue(right, i),
      },
    });
  }

  static const _leftHotCueKeys = [
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
  ];
  static const _rightHotCueKeys = [
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
    PhysicalKeyboardKey.digit9,
    PhysicalKeyboardKey.digit0,
  ];

  /// The command for [key], or null when the key isn't bound.
  ///
  /// When Shift is held and there is no Shift binding, the plain binding
  /// is used. So Shift + `[` still plays (the user typed `{`).
  MixerCommand? lookup(PhysicalKeyboardKey key, {bool shift = false}) {
    return _bindings[(key: key, shift: shift)] ??
        (shift ? _bindings[(key: key, shift: false)] : null);
  }
}
