import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef ScanPluginsC = Pointer<Utf8> Function(Pointer<Utf8> directory);
typedef ScanPluginsDart = Pointer<Utf8> Function(Pointer<Utf8> directory);

typedef LoadPluginC = Pointer<Void> Function(Pointer<Utf8> path);
typedef LoadPluginDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef UnloadPluginC = Void Function(Pointer<Void> handle);
typedef UnloadPluginDart = void Function(Pointer<Void> handle);

typedef SetGainC = Void Function(Pointer<Void> handle, Double normalized);
typedef SetGainDart = void Function(Pointer<Void> handle, double normalized);

typedef GetLevelC = Double Function(Pointer<Void> handle);
typedef GetLevelDart = double Function(Pointer<Void> handle);

typedef OpenEditorC = Void Function(Pointer<Void> handle);
typedef OpenEditorDart = void Function(Pointer<Void> handle);

typedef CloseEditorC = Void Function(Pointer<Void> handle);
typedef CloseEditorDart = void Function(Pointer<Void> handle);

typedef FreeStringC = Void Function(Pointer<Utf8> str);
typedef FreeStringDart = void Function(Pointer<Utf8> str);

/// Bindings against native/yuvi_vst_host's C ABI
/// (include/yuvi_vst_host_api.h). Loaded lazily — [instance] is null
/// (rather than throwing) if the native library hasn't been built yet,
/// so the rest of the app degrades to the stub controller gracefully.
class VstHostBindings {
  VstHostBindings._(DynamicLibrary lib)
      : scanPlugins = lib.lookupFunction<ScanPluginsC, ScanPluginsDart>('yvh_scan_plugins'),
        loadPlugin = lib.lookupFunction<LoadPluginC, LoadPluginDart>('yvh_load_plugin'),
        unloadPlugin = lib.lookupFunction<UnloadPluginC, UnloadPluginDart>('yvh_unload_plugin'),
        setGain = lib.lookupFunction<SetGainC, SetGainDart>('yvh_set_gain'),
        getLevel = lib.lookupFunction<GetLevelC, GetLevelDart>('yvh_get_level'),
        openEditor = lib.lookupFunction<OpenEditorC, OpenEditorDart>('yvh_open_editor'),
        closeEditor = lib.lookupFunction<CloseEditorC, CloseEditorDart>('yvh_close_editor'),
        freeString = lib.lookupFunction<FreeStringC, FreeStringDart>('yvh_free_string');

  final ScanPluginsDart scanPlugins;
  final LoadPluginDart loadPlugin;
  final UnloadPluginDart unloadPlugin;
  final SetGainDart setGain;
  final GetLevelDart getLevel;
  final OpenEditorDart openEditor;
  final CloseEditorDart closeEditor;
  final FreeStringDart freeString;

  static VstHostBindings? _tryLoad() {
    try {
      final DynamicLibrary lib;
      if (Platform.isMacOS) {
        lib = DynamicLibrary.open('libyuvi_vst_host.dylib');
      } else if (Platform.isWindows) {
        lib = DynamicLibrary.open('yuvi_vst_host.dll');
      } else {
        return null; // Linux/other: not a target platform for this feature.
      }
      return VstHostBindings._(lib);
    } catch (_) {
      // Not built yet — see native/yuvi_vst_host/README.md.
      return null;
    }
  }

  static final VstHostBindings? instance = _tryLoad();
}
