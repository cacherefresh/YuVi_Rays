import 'midi_profile.dart';

/// Where the user's mapping choices are kept, e.g. the browser's
/// localStorage. Injected so the registry stays pure and testable.
abstract interface class MidiMappingStore {
  String? read(String key);

  /// Writes [value], or removes the key when it's null.
  void write(String key, String? value);
}

/// A [MidiMappingStore] in memory, for tests and non-browser use.
class InMemoryMidiMappingStore implements MidiMappingStore {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String? value) =>
      value == null ? values.remove(key) : values[key] = value;
}

/// Decides which [MidiProfile] each device uses. Highest wins:
///
/// 1. The user's choice for that device: a bundled profile, or a custom
///    one they imported (Settings → MIDI mapping).
/// 2. A bundled profile whose `device_name_contains` matches the name.
/// 3. The fallback (generic) profile.
class MidiProfileRegistry {
  MidiProfileRegistry({
    required this.bundled,
    required this.fallback,
    MidiMappingStore? store,
  }) : store = store ?? InMemoryMidiMappingStore();

  /// Choice value meaning "pick automatically by device name".
  static const automatic = '';

  /// Choice value meaning "use this device's imported custom profile".
  static const custom = '@custom';

  final List<MidiProfile> bundled;
  final MidiProfile fallback;
  final MidiMappingStore store;

  /// Every bundled profile plus the fallback, for a picker.
  List<MidiProfile> get all => [...bundled, fallback];

  String _choiceKey(String device) => 'yuvi.midi.profileChoice.$device';
  String _customKey(String device) => 'yuvi.midi.custom.$device';

  /// [automatic], [custom], or a bundled profile name.
  String choiceFor(String device) => store.read(_choiceKey(device)) ?? automatic;

  /// The device's imported custom profile, if any (invalid YAML is ignored).
  MidiProfile? customFor(String device) {
    final yaml = store.read(_customKey(device));
    if (yaml == null) return null;
    try {
      return MidiProfile.fromYaml(yaml);
    } on FormatException {
      return null;
    }
  }

  MidiProfile resolve(String device) {
    final choice = choiceFor(device);
    if (choice == custom) {
      final c = customFor(device);
      if (c != null) return c;
    } else if (choice != automatic) {
      for (final p in all) {
        if (p.name == choice) return p;
      }
    }
    return MidiProfile.select(device, bundled, fallback: fallback);
  }

  /// Use a bundled profile by [profileName], or [automatic].
  void choose(String device, String profileName) =>
      store.write(_choiceKey(device), profileName == automatic ? null : profileName);

  /// Switch back to the device's previously imported custom profile.
  void chooseCustom(String device) {
    if (store.read(_customKey(device)) != null) store.write(_choiceKey(device), custom);
  }

  /// Validates [yaml] and makes it the device's custom profile.
  /// Throws [FormatException] (naming the bad entry) when it's invalid.
  MidiProfile importCustom(String device, String yaml) {
    final profile = MidiProfile.fromYaml(yaml);
    store.write(_customKey(device), yaml);
    store.write(_choiceKey(device), custom);
    return profile;
  }

  /// Forgets the device's custom profile and choice: back to automatic.
  void reset(String device) {
    store.write(_customKey(device), null);
    store.write(_choiceKey(device), null);
  }
}
