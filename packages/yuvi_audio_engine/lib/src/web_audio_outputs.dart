import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'contracts/audio_outputs.dart';
import 'js_bridge.dart';

/// [AudioOutputs] backed by the browser: `enumerateDevices` to list, and a
/// hidden `<audio>` element with `setSinkId` to play the headphone mix.
///
/// Bridge events (`headphones`, `outputDevicesChanged`) arrive through
/// [handleEvent], called by whoever owns the bridge callback.
class WebAudioOutputs extends ChangeNotifier implements AudioOutputs {
  WebAudioOutputs() : supported = yuViDVS.headphonesSupported() {
    if (!supported) _status = HeadphoneStatus.unsupported;
  }

  @override
  final bool supported;

  HeadphoneStatus _status = HeadphoneStatus.off;
  String? _message;
  String? _deviceId;
  String? _deviceName;

  int _devicesVersion = 0;

  @override
  int get devicesVersion => _devicesVersion;

  @override
  HeadphoneStatus get status => _status;
  @override
  String? get statusMessage => _message;
  @override
  String? get headphoneDeviceId => _deviceId;
  @override
  String? get headphoneDeviceName => _deviceName;

  @override
  Future<OutputDeviceList> list({bool askPermission = false}) async {
    if (!supported) return const OutputDevicesFailed('unsupported');
    final json = (await yuViDVS.listOutputDevices(askPermission).toDart).toDart;
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return OutputDevicesFailed('${decoded['error'] ?? 'unknown'}');
    }
    return OutputDevicesFound([
      for (final d in decoded as List)
        AudioOutputDevice(id: d['id'] as String, name: d['name'] as String),
    ]);
  }

  @override
  Future<void> setHeadphoneDevice(AudioOutputDevice? device) async {
    if (!supported) return;
    _deviceId = device?.id;
    _deviceName = device?.name;
    notifyListeners();
    await yuViDVS.setHeadphoneSink(device?.id, device?.name).toDart;
  }

  /// Handles a bridge event. Returns true when it was an output event.
  bool handleEvent(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'headphones':
        _status = HeadphoneStatus.parse(data['status'] as String?);
        _message = data['message'] as String?;
        _deviceId = data['deviceId'] as String?;
        _deviceName = data['deviceName'] as String? ?? _deviceName;
        notifyListeners();
        return true;
      case 'outputDevicesChanged':
        _devicesVersion++;
        notifyListeners();
        return true;
    }
    return false;
  }
}
