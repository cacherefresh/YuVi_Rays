import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../input_source.dart';
import '../mixer_command.dart';
import 'keyboard_bindings.dart';

/// Emits [MixerCommand]s for bound keys, app-wide.
///
/// Uses a global [HardwareKeyboard] handler, so it works no matter which
/// widget has focus. Keys are ignored while a text field is focused, and
/// held-key auto-repeat is ignored.
class KeyboardInputSource implements InputSource {
  KeyboardInputSource({KeyboardBindings? bindings})
      : bindings = bindings ?? KeyboardBindings.diagonalColumns();

  final KeyboardBindings bindings;
  final _controller = StreamController<MixerCommand>.broadcast();
  bool _listening = false;

  @override
  Stream<MixerCommand> get commands => _controller.stream;

  @override
  Future<void> start() async {
    if (_listening) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _listening = true;
  }

  @override
  Future<void> stop() async {
    if (!_listening) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _listening = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_isTextFieldFocused()) return false;
    final command = bindings.lookup(
      event.physicalKey,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );
    if (command == null) return false;
    _controller.add(command);
    return true; // handled: stops the browser acting on the key too
  }

  static bool _isTextFieldFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
