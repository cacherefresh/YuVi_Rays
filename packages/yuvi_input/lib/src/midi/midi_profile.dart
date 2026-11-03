import 'package:yaml/yaml.dart';

import 'midi_message.dart';

/// What a knob (or fader) can control. The value is mapped from 0..127 to
/// the binding's [KnobBinding.min]..[KnobBinding.max].
enum KnobAction {
  channelVolume(deck: true, min: 0, max: 1),
  masterVolume(deck: false, min: 0, max: 1),
  headphoneVolume(deck: false, min: 0, max: 1),
  crossfader(deck: false, min: 0, max: 1),
  pitchCoarse(deck: true, min: -16, max: 16),
  pitchFine(deck: true, min: -1, max: 1);

  const KnobAction({required this.deck, required this.min, required this.max});

  /// Whether the action needs a `deck`.
  final bool deck;

  /// Default range when the profile doesn't give one.
  final double min;
  final double max;
}

/// What a pad (or button) gesture can trigger. All of these act on a deck.
enum PadAction {
  togglePlay,
  stop,
  jumpToCue,
  setCue,
  playFromCue,
  armCue,
  commitCue,

  /// Needs `slot`: set the hot cue when empty, else jump to it.
  hotCue,

  /// Needs `slot`: empty the hot cue.
  clearHotCue;

  bool get needsSlot => this == hotCue || this == clearHotCue;
}

/// How a knob behaves when it doesn't match the on-screen value.
enum Takeover {
  /// Apply the knob's value immediately (the value may jump).
  jump,

  /// Ignore the knob until it reaches the current value (soft takeover).
  pickup,
}

/// A knob or fader sending control-change (CC) messages.
class KnobBinding {
  const KnobBinding({
    required this.cc,
    required this.action,
    required this.min,
    required this.max,
    this.channel,
    this.deckId,
    this.takeover = Takeover.jump,
  });

  final int cc;

  /// 1..16, or null for any channel.
  final int? channel;
  final KnobAction action;
  final String? deckId;
  final double min;
  final double max;
  final Takeover takeover;

  bool matches(MidiMessage m) =>
      m.type == MidiMessageType.controlChange &&
      m.number == cc &&
      (channel == null || channel == m.channel);

  /// Maps a raw 0..127 value into [min]..[max].
  ///
  /// When the range spans zero (e.g. pitch −16..+16), the knob's centre
  /// value 64 maps to exactly 0, so the centre of the knob is "no change".
  double scale(int raw) {
    final v = raw.clamp(0, 127);
    if (min < 0 && max > 0) {
      return v < 64 ? min * (64 - v) / 64 : max * (v - 64) / 63;
    }
    return min + (max - min) * v / 127;
  }

  /// Pick-up tolerance in value units: 3% of the range.
  double get pickupTolerance => (max - min).abs() * 0.03;
}

/// A pad or button, sending notes or CC (press = note-on or CC ≥ 64).
///
/// A pad can do something on press, on a short tap (released before
/// [holdMs]), and on a hold (still pressed at [holdMs]).
class PadBinding {
  const PadBinding({
    required this.deckId,
    this.note,
    this.cc,
    this.channel,
    this.onPress,
    this.onTap,
    this.onHold,
    this.holdMs = 1000,
    this.slot,
  }) : assert((note == null) != (cc == null), 'exactly one of note or cc');

  /// Hot cue slot 1..4 for [PadAction.hotCue] and [PadAction.clearHotCue].
  final int? slot;

  final int? note;
  final int? cc;
  final int? channel;
  final String deckId;
  final PadAction? onPress;
  final PadAction? onTap;
  final PadAction? onHold;
  final int holdMs;

  /// True for a press, false for a release, null when not this pad.
  bool? pressOrRelease(MidiMessage m) {
    if (channel != null && channel != m.channel) return null;
    if (note != null && m.number == note) {
      if (m.type == MidiMessageType.noteOn) return true;
      if (m.type == MidiMessageType.noteOff) return false;
    }
    if (cc != null && m.number == cc && m.type == MidiMessageType.controlChange) {
      return m.value >= 64;
    }
    return null;
  }
}

/// A controller mapping, loaded from YAML (JSON is valid YAML too).
///
/// ```yaml
/// name: Akai MPK Mini Mk II
/// device_name_contains: [MPK Mini Mk II]
/// verified: false
/// knobs:
///   - { cc: 1, action: channelVolume, deck: A }
///   - { cc: 2, action: pitchCoarse, deck: A, min: -16, max: 16, takeover: pickup }
/// pads:
///   - { note: 44, deck: A, on_press: togglePlay }
///   - { note: 45, deck: A, on_press: armCue, on_tap: playFromCue, on_hold: commitCue, hold_ms: 1000 }
/// ```
class MidiProfile {
  const MidiProfile({
    required this.name,
    this.knobs = const [],
    this.pads = const [],
    this.deviceNameContains = const [],
    this.verified = false,
  });

  final String name;
  final List<KnobBinding> knobs;
  final List<PadBinding> pads;

  /// Case-insensitive substrings of the MIDI device name this profile is for.
  /// Empty means "fallback for unknown devices".
  final List<String> deviceNameContains;

  /// True once the numbers have been checked on real hardware.
  final bool verified;

  /// Parses a profile. Throws [FormatException] naming the bad entry.
  factory MidiProfile.fromYaml(String text) {
    final doc = loadYaml(text);
    if (doc is! Map) throw const FormatException('A MIDI profile must be a map');
    return MidiProfile.fromMap(_plain(doc) as Map<String, dynamic>);
  }

  factory MidiProfile.fromMap(Map<String, dynamic> m) {
    final name = m['name'];
    if (name is! String) throw const FormatException('Missing "name"');
    final knobs = <KnobBinding>[];
    for (final (i, k) in _list(m['knobs']).indexed) {
      knobs.add(_wrap('knobs[$i]', () => _knob(_map(k))));
    }
    final pads = <PadBinding>[];
    for (final (i, p) in _list(m['pads']).indexed) {
      pads.add(_wrap('pads[$i]', () => _pad(_map(p))));
    }
    return MidiProfile(
      name: name,
      knobs: knobs,
      pads: pads,
      deviceNameContains: _list(m['device_name_contains']).cast<String>(),
      verified: m['verified'] as bool? ?? false,
    );
  }

  /// Writes the profile as YAML that [MidiProfile.fromYaml] reads back.
  /// Used by "Export" in Settings, so a user can edit it and import it.
  String toYaml() {
    String q(String v) => "'${v.replaceAll("'", "''")}'";
    String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    final b = StringBuffer()
      ..writeln('# YuVi Rays MIDI profile. Edit, then import it in Settings → MIDI mapping.')
      ..writeln('# Format: DJ_SETUP_INSTRUCTIONS.md and assets/midi_profiles/*.yaml')
      ..writeln('name: ${q(name)}')
      ..writeln('device_name_contains: [${deviceNameContains.map(q).join(', ')}]')
      ..writeln('verified: $verified');
    if (knobs.isNotEmpty) {
      b.writeln('knobs:');
      for (final k in knobs) {
        b.writeln('  - { cc: ${k.cc}'
            '${k.channel == null ? '' : ', channel: ${k.channel}'}'
            ', action: ${k.action.name}'
            '${k.deckId == null ? '' : ', deck: ${q(k.deckId!)}'}'
            ', min: ${fmt(k.min)}, max: ${fmt(k.max)}'
            '${k.takeover == Takeover.jump ? '' : ', takeover: ${k.takeover.name}'} }');
      }
    }
    if (pads.isNotEmpty) {
      b.writeln('pads:');
      for (final p in pads) {
        b.writeln('  - { ${p.note != null ? 'note: ${p.note}' : 'cc: ${p.cc}'}'
            '${p.channel == null ? '' : ', channel: ${p.channel}'}'
            ', deck: ${q(p.deckId)}'
            '${p.slot == null ? '' : ', slot: ${p.slot}'}'
            '${p.onPress == null ? '' : ', on_press: ${p.onPress!.name}'}'
            '${p.onTap == null ? '' : ', on_tap: ${p.onTap!.name}'}'
            '${p.onHold == null ? '' : ', on_hold: ${p.onHold!.name}, hold_ms: ${p.holdMs}'} }');
      }
    }
    return b.toString();
  }

  bool matchesDevice(String deviceName) {
    final lower = deviceName.toLowerCase();
    return deviceNameContains.any((s) => lower.contains(s.toLowerCase()));
  }

  /// Picks the first profile whose [deviceNameContains] matches, else [fallback].
  static MidiProfile select(
    String deviceName,
    List<MidiProfile> profiles, {
    required MidiProfile fallback,
  }) {
    for (final p in profiles) {
      if (p.matchesDevice(deviceName)) return p;
    }
    return fallback;
  }

  // ── parsing helpers ────────────────────────────────────────────────

  static KnobBinding _knob(Map<String, dynamic> k) {
    final action = _enum(KnobAction.values, k['action'], 'action');
    final deck = k['deck'] as String?;
    if (action.deck && deck == null) {
      throw FormatException('"${action.name}" needs a "deck"');
    }
    return KnobBinding(
      cc: _int(k['cc'], 'cc'),
      channel: _channel(k['channel']),
      action: action,
      deckId: deck,
      min: (k['min'] as num?)?.toDouble() ?? action.min,
      max: (k['max'] as num?)?.toDouble() ?? action.max,
      takeover: k['takeover'] == null
          ? Takeover.jump
          : _enum(Takeover.values, k['takeover'], 'takeover'),
    );
  }

  static PadBinding _pad(Map<String, dynamic> p) {
    final hasNote = p['note'] != null, hasCc = p['cc'] != null;
    if (hasNote == hasCc) throw const FormatException('needs exactly one of "note" or "cc"');
    final deck = p['deck'];
    if (deck is! String) throw const FormatException('needs a "deck"');
    PadAction? action(String key) =>
        p[key] == null ? null : _enum(PadAction.values, p[key], key);
    final pad = PadBinding(
      note: hasNote ? _int(p['note'], 'note') : null,
      cc: hasCc ? _int(p['cc'], 'cc') : null,
      channel: _channel(p['channel']),
      deckId: deck,
      onPress: action('on_press'),
      onTap: action('on_tap'),
      onHold: action('on_hold'),
      holdMs: (p['hold_ms'] as int?) ?? 1000,
      slot: p['slot'] as int?,
    );
    final actions = [pad.onPress, pad.onTap, pad.onHold].whereType<PadAction>();
    if (actions.any((a) => a.needsSlot) && (pad.slot == null || pad.slot! < 1 || pad.slot! > 4)) {
      throw const FormatException('hot cue actions need "slot" 1..4');
    }
    if (pad.onPress == null && pad.onTap == null && pad.onHold == null) {
      throw const FormatException('needs at least one of on_press, on_tap, on_hold');
    }
    return pad;
  }

  static T _wrap<T>(String where, T Function() f) {
    try {
      return f();
    } on FormatException catch (e) {
      throw FormatException('$where: ${e.message}');
    }
  }

  static T _enum<T extends Enum>(List<T> values, Object? raw, String key) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    throw FormatException(
        'unknown $key "$raw" (expected one of ${values.map((v) => v.name).join(', ')})');
  }

  static int _int(Object? raw, String key) {
    if (raw is int && raw >= 0 && raw <= 127) return raw;
    throw FormatException('"$key" must be a number 0..127, got "$raw"');
  }

  static int? _channel(Object? raw) {
    if (raw == null) return null;
    if (raw is int && raw >= 1 && raw <= 16) return raw;
    throw FormatException('"channel" must be 1..16, got "$raw"');
  }

  static List<dynamic> _list(Object? raw) => raw == null ? const [] : raw as List;
  static Map<String, dynamic> _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw const FormatException('each entry must be a map');
  }

  /// YamlMap/YamlList → plain Dart maps and lists.
  static Object? _plain(Object? node) => switch (node) {
        Map() => {for (final e in node.entries) e.key.toString(): _plain(e.value)},
        List() => [for (final e in node) _plain(e)],
        _ => node,
      };
}
