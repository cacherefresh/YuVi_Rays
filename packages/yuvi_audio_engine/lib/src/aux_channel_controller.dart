import 'dart:convert';

import 'js_bridge.dart';
import 'models/aux_state.dart';

class AudioInputDevice {
  const AudioInputDevice({required this.id, required this.label});
  final String id;
  final String label;
}

class AuxChannelController {
  final AuxState state;

  AuxChannelController(this.state) {
    yuViDVS.initAux();
  }

  Future<List<AudioInputDevice>> listInputDevices() async {
    final raw = await yuViDVS.listAudioInputsAsync();
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => AudioInputDevice(
              id: e['id'] as String,
              label: e['label'] as String,
            ))
        .toList();
  }

  Future<void> selectInput(AudioInputDevice device) async {
    await yuViDVS.selectAuxInputAsync(device.id);
    state.update(
      selectedDeviceId: device.id,
      deviceLabel: device.label,
      isActive: true,
    );
  }

  void setGain(double normalized) {
    state.update(gain: normalized);
    yuViDVS.setAuxGain(normalized.clamp(0.0, 1.0));
  }

  void setVolume(double normalized) {
    state.update(volume: normalized);
    yuViDVS.setAuxVolume(normalized.clamp(0.0, 1.0));
  }

  double getLevel() => yuViDVS.getAuxLevel();
}
