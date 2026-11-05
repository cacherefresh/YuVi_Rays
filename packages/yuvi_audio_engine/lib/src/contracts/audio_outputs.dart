/// Choosing where the master (speakers) and the headphone cue mix play.
///
/// Device choice is setup, not mixing, so it is separate from
/// [MixerControls]. Pure Dart: the browser implementation is
/// `WebAudioOutputs`; tests can use a fake.
library;

import 'package:flutter/foundation.dart';

/// An audio output the browser can see.
@immutable
class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'AudioOutputDevice($name)';
}

enum HeadphoneStatus {
  /// No device chosen: the headphone mix plays nowhere.
  off,
  connecting,
  playing,

  /// Chosen, but the browser needs a click or key press before it plays.
  waitingForClick,

  /// The chosen device was unplugged. Plays again when it comes back.
  lost,
  error,

  /// The browser can't send audio to a second device (e.g. Safari).
  unsupported;

  static HeadphoneStatus parse(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => error);
}

/// Result of listing devices.
sealed class OutputDeviceList {
  const OutputDeviceList();
}

final class OutputDevicesFound extends OutputDeviceList {
  const OutputDevicesFound(this.devices);
  final List<AudioOutputDevice> devices;

  /// True when the browser hid the names (no microphone permission yet).
  bool get namesHidden => devices.every((d) => d.name == 'Unnamed output');
}

final class OutputDevicesFailed extends OutputDeviceList {
  const OutputDevicesFailed(this.reason);

  /// e.g. `NotAllowedError` (microphone permission refused), `unsupported`.
  final String reason;
}

/// Lists output devices, and sends the master and the headphone mix to them.
/// Notifies listeners when a status or the device list changes.
abstract interface class AudioOutputs implements Listenable {
  /// The headphone output can be sent to a device.
  bool get supported;

  /// The master output can be moved off the system default device.
  bool get masterSupported;

  /// The master's device, or null for the system default.
  String? get masterDeviceId;
  String? get masterDeviceName;

  /// Why the last master device change failed, or null.
  String? get masterError;

  /// Sends the master to the device; null = the system default.
  Future<void> setMasterDevice(AudioOutputDevice? device);

  HeadphoneStatus get status;

  /// Detail for [HeadphoneStatus.error], or null.
  String? get statusMessage;

  /// The chosen device, or null.
  String? get headphoneDeviceId;
  String? get headphoneDeviceName;

  /// Goes up each time the browser's device list changes (plug / unplug),
  /// so a picker knows when to list again.
  int get devicesVersion;

  /// Lists outputs. With [askPermission], Chrome may show its microphone
  /// prompt, because it hides device names until that is granted.
  Future<OutputDeviceList> list({bool askPermission = false});

  /// Sends the headphone mix to the device; null turns headphones off.
  Future<void> setHeadphoneDevice(AudioOutputDevice? device);
}
