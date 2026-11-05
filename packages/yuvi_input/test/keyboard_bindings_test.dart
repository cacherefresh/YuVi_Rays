import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_input/src/keyboard/keyboard_bindings.dart';
import 'package:yuvi_input/src/mixer_command.dart';

void main() {
  final b = KeyboardBindings.diagonalColumns();

  test('left column drives deck A', () {
    expect(b.lookup(PhysicalKeyboardKey.bracketLeft), isA<TogglePlay>().having((c) => c.deckId, 'deck', 'A'));
    expect(b.lookup(PhysicalKeyboardKey.semicolon), isA<JumpToCue>().having((c) => c.deckId, 'deck', 'A'));
    expect(b.lookup(PhysicalKeyboardKey.period), isA<Stop>().having((c) => c.deckId, 'deck', 'A'));
  });

  test('right column drives deck B', () {
    expect(b.lookup(PhysicalKeyboardKey.bracketRight), isA<TogglePlay>().having((c) => c.deckId, 'deck', 'B'));
    expect(b.lookup(PhysicalKeyboardKey.quote), isA<JumpToCue>().having((c) => c.deckId, 'deck', 'B'));
    expect(b.lookup(PhysicalKeyboardKey.slash), isA<Stop>().having((c) => c.deckId, 'deck', 'B'));
  });

  test('P and backslash toggle the headphone cue (PFL) for A and B', () {
    expect(b.lookup(PhysicalKeyboardKey.keyP), isA<ToggleHeadphoneCue>().having((c) => c.deckId, 'deck', 'A'));
    expect(b.lookup(PhysicalKeyboardKey.backslash), isA<ToggleHeadphoneCue>().having((c) => c.deckId, 'deck', 'B'));
  });

  test('Shift on the cue key sets the cue', () {
    expect(b.lookup(PhysicalKeyboardKey.semicolon, shift: true), isA<SetCue>());
    expect(b.lookup(PhysicalKeyboardKey.quote, shift: true), isA<SetCue>());
  });

  test('Shift on a key without a Shift binding falls back to the plain one', () {
    // User typing "{" still plays deck A.
    expect(b.lookup(PhysicalKeyboardKey.bracketLeft, shift: true), isA<TogglePlay>());
  });

  test('unbound keys return null', () {
    expect(b.lookup(PhysicalKeyboardKey.keyQ), isNull);
  });
}
