import 'package:flutter/foundation.dart';

class VstPluginInfo {
  const VstPluginInfo({required this.name, required this.path, required this.format});
  final String name;
  final String path;

  /// 'VST3' or 'AU'.
  final String format;
}

/// State for the native VST channel (Desktop only). Deliberately platform-
/// agnostic (no ffi/js imports) so both [VstChannelController]
/// implementations — stub and native — can share it without duplication.
class VstChannelState extends ChangeNotifier {
  String? pluginName;
  bool isLoaded = false;
  double gain = 0.8;

  void update({String? pluginName, bool? isLoaded, double? gain}) {
    var changed = false;

    if (pluginName != this.pluginName) {
      this.pluginName = pluginName;
      changed = true;
    }
    if (isLoaded != null && isLoaded != this.isLoaded) {
      this.isLoaded = isLoaded;
      changed = true;
    }
    if (gain != null) {
      final clamped = gain.clamp(0.0, 1.0);
      if (clamped != this.gain) {
        this.gain = clamped;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }
}
