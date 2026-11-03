import 'package:flutter/foundation.dart';

/// State for the third mixer channel — a virtual-audio-input strip (fader
/// + gain, no platter) that a real VST running in a DAW/standalone host
/// can be routed into via a virtual audio cable (BlackHole/VB-Cable).
class AuxState extends ChangeNotifier {
  String? selectedDeviceId;
  String? deviceLabel;
  bool isActive = false;
  double gain = 0.8;
  double volume = 0.8;

  void update({
    String? selectedDeviceId,
    String? deviceLabel,
    bool? isActive,
    double? gain,
    double? volume,
  }) {
    var changed = false;

    if (selectedDeviceId != null && selectedDeviceId != this.selectedDeviceId) {
      this.selectedDeviceId = selectedDeviceId;
      changed = true;
    }
    if (deviceLabel != null && deviceLabel != this.deviceLabel) {
      this.deviceLabel = deviceLabel;
      changed = true;
    }
    if (isActive != null && isActive != this.isActive) {
      this.isActive = isActive;
      changed = true;
    }
    if (gain != null) {
      final clamped = gain.clamp(0.0, 1.0);
      if (clamped != this.gain) {
        this.gain = clamped;
        changed = true;
      }
    }
    if (volume != null) {
      final clamped = volume.clamp(0.0, 1.0);
      if (clamped != this.volume) {
        this.volume = clamped;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }
}
