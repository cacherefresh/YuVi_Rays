import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../input_source.dart';
import '../mixer_command.dart';
import 'midi_mapper.dart';
import 'midi_message.dart';
import 'midi_profile.dart';
import 'midi_profile_registry.dart';

enum MidiStatus {
  /// MIDI is switched off in settings.
  off,

  /// Waiting for the user to answer Chrome's permission prompt.
  requesting,

  /// The browser has no Web MIDI API (e.g. Safari).
  unsupported,

  /// The user (or browser policy) blocked MIDI access.
  denied,

  /// Access granted, but no input device is plugged in.
  noDevice,

  /// At least one input device is connected.
  connected,
}

/// Observable connection info for the settings UI.
class MidiConnectionState extends ChangeNotifier {
  MidiStatus status = MidiStatus.off;

  /// Connected device name → profile name in use.
  Map<String, String> devices = const {};

  /// Last message received, for the "MIDI monitor" line.
  String? lastMessage;

  String? error;

  void _set({
    MidiStatus? status,
    Map<String, String>? devices,
    String? lastMessage,
    String? error,
  }) {
    if (status != null) this.status = status;
    if (devices != null) this.devices = devices;
    if (lastMessage != null) this.lastMessage = lastMessage;
    this.error = error ?? (status != null ? null : this.error);
    notifyListeners();
  }
}

/// Reads every connected MIDI input through the browser's Web MIDI API and
/// emits [MixerCommand]s, using the [MidiProfile] matched to each device.
///
/// Calling [start] makes Chrome show its MIDI permission prompt the first
/// time. Call it from a user action (e.g. a settings switch).
/// Devices plugged in or removed later are picked up automatically.
class MidiInputSource implements InputSource {
  MidiInputSource({required this.registry});

  /// Decides which profile each device uses.
  final MidiProfileRegistry registry;
  final connection = MidiConnectionState();

  final _controller = StreamController<MixerCommand>.broadcast();
  web.MIDIAccess? _access;
  final _inputs = <web.MIDIInput>[];
  final _mappers = <String, MidiMapper>{};

  @override
  Stream<MixerCommand> get commands => _controller.stream;

  static bool get isSupported =>
      (web.window.navigator as JSObject).has('requestMIDIAccess');

  @override
  Future<void> start() async {
    if (_access != null) return;
    if (!isSupported) {
      connection._set(status: MidiStatus.unsupported);
      return;
    }
    connection._set(status: MidiStatus.requesting);
    try {
      final access = await web.window.navigator.requestMIDIAccess().toDart;
      _access = access;
      access.onstatechange = ((web.Event _) => _attachInputs()).toJS;
      _attachInputs();
    } catch (e) {
      connection._set(status: MidiStatus.denied, error: e.toString());
    }
  }

  @override
  Future<void> stop() async {
    _detachInputs();
    _access?.onstatechange = null;
    _access = null;
    connection._set(status: MidiStatus.off, devices: const {});
  }

  @override
  Future<void> dispose() async {
    await stop();
    connection.dispose();
    await _controller.close();
  }

  void _attachInputs() {
    final access = _access;
    if (access == null) return;
    _detachInputs();

    final devices = <String, String>{};
    // MIDIInputMap is a JS Map-like; iterate with its forEach.
    (access.inputs as JSObject).callMethod(
      'forEach'.toJS,
      ((web.MIDIInput input, JSAny? _) {
        if (input.state != 'connected') return;
        final name = input.name ?? 'Unknown device';
        final mapper = _mapperFor(name);
        devices[name] = mapper.profile.name;
        input.onmidimessage = ((web.MIDIMessageEvent event) {
          final data = event.data;
          if (data != null) inject(name, data.toDart);
        }).toJS;
        _inputs.add(input);
      }).toJS,
    );

    connection._set(
      status: devices.isEmpty ? MidiStatus.noDevice : MidiStatus.connected,
      devices: devices,
    );
  }

  void _detachInputs() {
    for (final input in _inputs) {
      input.onmidimessage = null;
    }
    _inputs.clear();
    for (final m in _mappers.values) {
      m.dispose();
    }
    _mappers.clear();
  }

  MidiMapper _mapperFor(String deviceName) => _mappers.putIfAbsent(
        deviceName,
        () => MidiMapper(
          registry.resolve(deviceName),
          emit: _controller.add,
        ),
      );

  /// Re-reads each device's profile from the [registry], e.g. after the
  /// user picks or imports a mapping in Settings.
  void refreshMappings() {
    for (final m in _mappers.values) {
      m.dispose();
    }
    _mappers.clear();
    _attachInputs();
  }

  /// The profile the device [deviceName] currently uses.
  MidiProfile profileFor(String deviceName) => _mapperFor(deviceName).profile;

  /// Feeds raw MIDI [bytes] as if they came from the device [deviceName].
  ///
  /// Real messages from connected devices arrive here too. Tests and the
  /// debug-build hook use it to drive the app without hardware.
  void inject(String deviceName, List<int> bytes) {
    final message = MidiMessage.parse(bytes);
    if (message == null) return;
    connection._set(lastMessage: message.describe());
    _mapperFor(deviceName).handle(message);
  }
}
