/// Keyboard and MIDI input for mixers, as a stream of typed [MixerCommand]s.
///
/// Pure Dart and Flutter only: safe on the Dart VM (unit tests, CI).
/// The browser Web MIDI source is in `yuvi_input_web.dart`.
library;

export 'src/mixer_command.dart';
export 'src/input_source.dart';
export 'src/soft_takeover.dart';
export 'src/keyboard/keyboard_bindings.dart';
export 'src/keyboard/keyboard_input_source.dart';
export 'src/midi/midi_message.dart';
export 'src/midi/midi_profile.dart';
export 'src/midi/midi_profile_registry.dart';
export 'src/midi/midi_mapper.dart';
