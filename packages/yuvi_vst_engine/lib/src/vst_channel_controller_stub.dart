import 'models/vst_channel_state.dart';

/// No-op VST channel controller used wherever the native engine isn't
/// available — the Flutter Web build (dart:ffi can't compile there at
/// all) or a native build where native/yuvi_vst_host hasn't been built
/// yet. See vst_channel_controller_native.dart for the real dart:ffi
/// implementation and native/yuvi_vst_host/README.md for build status.
class VstChannelController {
  VstChannelController(this.state);
  final VstChannelState state;

  bool get isNativeEngineAvailable => false;

  Future<List<VstPluginInfo>> scanPlugins(String directory) async => const [];
  Future<void> loadPlugin(String path) async {}
  void setGain(double normalized) {}
  double getLevel() => -100.0;
  void openEditor() {}
  void closeEditor() {}
}
