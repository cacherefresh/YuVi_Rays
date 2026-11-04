import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yuvi_input/yuvi_input_web.dart';

import '../settings/app_settings.dart';
import '../settings/local_storage_midi_store.dart';
import 'command_dispatcher.dart';
import 'debug_midi_hook.dart';

/// Owns the keyboard and MIDI input sources and routes their commands to
/// the [CommandDispatcher]. Turns MIDI on and off when the setting changes.
class InputController {
  InputController({
    required this.dispatch,
    required this.settings,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle {
    _subs.add(keyboard.commands.listen(dispatch.call));
    keyboard.start();
    settings.addListener(_applySettings);
    _ready = _loadMidi();
  }

  static const _profileDir = 'assets/midi_profiles/';

  final CommandDispatcher dispatch;
  final AppSettings settings;
  final AssetBundle _bundle;

  final keyboard = KeyboardInputSource();

  /// Null until the MIDI profiles have loaded.
  MidiInputSource? midi;

  /// Which profile each device uses; null until the profiles have loaded.
  MidiProfileRegistry? registry;

  final _subs = <StreamSubscription<MixerCommand>>[];
  late final Future<void> _ready;

  Future<void> _loadMidi() async {
    final profiles = await _loadProfiles();
    // The profile without device names is the fallback for unknown devices.
    final fallback = profiles.firstWhere(
      (p) => p.deviceNameContains.isEmpty,
      orElse: () => const MidiProfile(name: 'None'),
    );
    registry = MidiProfileRegistry(
      bundled: profiles.where((p) => p != fallback).toList(),
      fallback: fallback,
      store: LocalStorageMidiMappingStore(),
    );
    final source = MidiInputSource(registry: registry!);
    _subs.add(source.commands.listen(dispatch.call));
    midi = source;
    if (kDebugMode) installDebugMidiHook(source);
    _applySettings();
  }

  Future<List<MidiProfile>> _loadProfiles() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths = manifest.listAssets().where((p) =>
        p.startsWith(_profileDir) &&
        (p.endsWith('.yaml') || p.endsWith('.yml') || p.endsWith('.json')));
    final profiles = <MidiProfile>[];
    for (final path in paths) {
      try {
        profiles.add(MidiProfile.fromYaml(await _bundle.loadString(path)));
      } catch (e) {
        debugPrint('[InputController] skipping MIDI profile $path: $e');
      }
    }
    return profiles;
  }

  void _applySettings() {
    final source = midi;
    if (source == null) return;
    settings.midiEnabled ? source.start() : source.stop();
  }

  Future<void> dispose() async {
    settings.removeListener(_applySettings);
    await _ready;
    for (final s in _subs) {
      await s.cancel();
    }
    await keyboard.dispose();
    await midi?.dispose();
  }
}
