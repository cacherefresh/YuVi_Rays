import 'package:flutter/foundation.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';

/// [AudioOutputs] without a browser, for VM tests.
class FakeAudioOutputs extends ChangeNotifier implements AudioOutputs {
  FakeAudioOutputs({this.supported = true, this.masterSupported = true, this.devices = const []});

  @override
  final bool supported;
  @override
  final bool masterSupported;
  @override
  String? masterDeviceId;
  @override
  String? masterDeviceName;
  @override
  String? masterError;

  @override
  Future<void> setMasterDevice(AudioOutputDevice? device) async {
    masterDeviceId = device?.id;
    masterDeviceName = device?.name;
    notifyListeners();
  }
  final List<AudioOutputDevice> devices;

  @override
  HeadphoneStatus status = HeadphoneStatus.off;
  @override
  String? statusMessage;
  @override
  String? headphoneDeviceId;
  @override
  String? headphoneDeviceName;
  @override
  int devicesVersion = 0;

  @override
  Future<OutputDeviceList> list({bool askPermission = false}) async =>
      supported ? OutputDevicesFound(devices) : const OutputDevicesFailed('unsupported');

  @override
  Future<void> setHeadphoneDevice(AudioOutputDevice? device) async {
    headphoneDeviceId = device?.id;
    headphoneDeviceName = device?.name;
    status = device == null ? HeadphoneStatus.off : HeadphoneStatus.playing;
    notifyListeners();
  }
}
