import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// User settings, saved in the browser's localStorage so they survive reloads.
class AppSettings extends ChangeNotifier {
  AppSettings() {
    _midiEnabled = _read(_midiKey) == 'true';
    _midiHintSeen = _read(_midiHintKey) == 'true';
    _preferTagBpm = _read(_preferTagBpmKey) == 'true';
    _headphoneDeviceId = _read(_phonesIdKey);
    _headphoneDeviceName = _read(_phonesNameKey);
  }

  static const _phonesIdKey = 'yuvi.settings.headphoneDeviceId';
  static const _phonesNameKey = 'yuvi.settings.headphoneDeviceName';
  String? _headphoneDeviceId;
  String? _headphoneDeviceName;

  /// The headphone output device chosen last time, or null for none.
  /// Chrome keeps device IDs stable per site; the name is the fallback.
  String? get headphoneDeviceId => _headphoneDeviceId;
  String? get headphoneDeviceName => _headphoneDeviceName;

  void rememberHeadphoneDevice(String? id, String? name) {
    if (id == _headphoneDeviceId && name == _headphoneDeviceName) return;
    _headphoneDeviceId = id;
    _headphoneDeviceName = name;
    if (id == null) {
      _remove(_phonesIdKey);
      _remove(_phonesNameKey);
    } else {
      _write(_phonesIdKey, id);
      _write(_phonesNameKey, name ?? '');
    }
    notifyListeners();
  }

  static const _preferTagBpmKey = 'yuvi.settings.preferTagBpm';
  bool _preferTagBpm = false;

  /// Prefer the BPM in the MP3's tag over the detected BPM. Default off.
  /// Either source is still used when the other one is missing.
  bool get preferTagBpm => _preferTagBpm;

  set preferTagBpm(bool value) {
    if (value == _preferTagBpm) return;
    _preferTagBpm = value;
    _write(_preferTagBpmKey, value.toString());
    notifyListeners();
  }

  static const _midiKey = 'yuvi.settings.midiEnabled';
  static const _midiHintKey = 'yuvi.onboarding.midiHintSeen';

  bool _midiHintSeen = false;

  /// True once the first-visit "connect a MIDI controller" pop-up was shown.
  bool get midiHintSeen => _midiHintSeen;

  void markMidiHintSeen() {
    if (_midiHintSeen) return;
    _midiHintSeen = true;
    _write(_midiHintKey, 'true');
  }

  bool _midiEnabled = false;

  /// When true, the app asks Chrome for MIDI access (Chrome shows its
  /// permission prompt the first time) and listens to MIDI controllers.
  bool get midiEnabled => _midiEnabled;

  set midiEnabled(bool value) {
    if (value == _midiEnabled) return;
    _midiEnabled = value;
    _write(_midiKey, value.toString());
    notifyListeners();
  }

  // localStorage can throw in private windows or when site data is blocked.
  // Settings then simply aren't remembered.
  static String? _read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static void _write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  static void _remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
