import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'models/vst_channel_state.dart';
import 'vst_bindings.dart';

/// Real dart:ffi-backed VST channel controller — Desktop only (macOS/
/// Windows), since dart:ffi doesn't compile for web at all (see
/// vst_channel_controller.dart's conditional export). Degrades to no-ops
/// if native/yuvi_vst_host hasn't been built yet (VstHostBindings.instance
/// is null) rather than crashing — see that package's README.md.
class VstChannelController {
  VstChannelController(this.state);
  final VstChannelState state;

  Pointer<Void> _handle = nullptr;

  bool get isNativeEngineAvailable => VstHostBindings.instance != null;

  Future<List<VstPluginInfo>> scanPlugins(String directory) async {
    final bindings = VstHostBindings.instance;
    if (bindings == null) return const [];

    final dirPtr = directory.toNativeUtf8();
    try {
      final resultPtr = bindings.scanPlugins(dirPtr);
      final json = resultPtr.toDartString();
      bindings.freeString(resultPtr);
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => VstPluginInfo(
                name: e['name'] as String,
                path: e['path'] as String,
                format: e['format'] as String,
              ))
          .toList();
    } finally {
      malloc.free(dirPtr);
    }
  }

  Future<void> loadPlugin(String path) async {
    final bindings = VstHostBindings.instance;
    if (bindings == null) return;

    final pathPtr = path.toNativeUtf8();
    try {
      _handle = bindings.loadPlugin(pathPtr);
      state.update(
        pluginName: _handle == nullptr ? null : path.split('/').last,
        isLoaded: _handle != nullptr,
      );
    } finally {
      malloc.free(pathPtr);
    }
  }

  void setGain(double normalized) {
    state.update(gain: normalized);
    final bindings = VstHostBindings.instance;
    if (bindings != null && _handle != nullptr) {
      bindings.setGain(_handle, normalized.clamp(0.0, 1.0));
    }
  }

  double getLevel() {
    final bindings = VstHostBindings.instance;
    if (bindings == null || _handle == nullptr) return -100.0;
    return bindings.getLevel(_handle);
  }

  void openEditor() {
    final bindings = VstHostBindings.instance;
    if (bindings != null && _handle != nullptr) bindings.openEditor(_handle);
  }

  void closeEditor() {
    final bindings = VstHostBindings.instance;
    if (bindings != null && _handle != nullptr) bindings.closeEditor(_handle);
  }
}
