/// The MIDI message kinds the mixer cares about.
enum MidiMessageType { noteOn, noteOff, controlChange }

/// A parsed channel-voice MIDI message.
///
/// [channel] is 1..16, as printed on hardware and in manuals.
class MidiMessage {
  const MidiMessage({
    required this.type,
    required this.channel,
    required this.number,
    required this.value,
  });

  final MidiMessageType type;
  final int channel;

  /// Note number or CC number, 0..127.
  final int number;

  /// Velocity or CC value, 0..127.
  final int value;

  /// Parses raw MIDI bytes. Returns null for message types the mixer
  /// doesn't use (clock, SysEx, pitch bend, aftertouch, ...).
  static MidiMessage? parse(List<int> bytes) {
    if (bytes.length < 3) return null;
    final status = bytes[0] & 0xF0;
    final channel = (bytes[0] & 0x0F) + 1;
    final number = bytes[1] & 0x7F;
    final value = bytes[2] & 0x7F;
    final MidiMessageType type;
    switch (status) {
      case 0x90:
        // Note-on with velocity 0 is a note-off by MIDI convention.
        type = value == 0 ? MidiMessageType.noteOff : MidiMessageType.noteOn;
      case 0x80:
        type = MidiMessageType.noteOff;
      case 0xB0:
        type = MidiMessageType.controlChange;
      default:
        return null;
    }
    return MidiMessage(type: type, channel: channel, number: number, value: value);
  }

  /// Human-readable form for the settings monitor, e.g. `CC 70 · ch 1 · 64`.
  String describe() {
    final kind = switch (type) {
      MidiMessageType.noteOn => 'Note on',
      MidiMessageType.noteOff => 'Note off',
      MidiMessageType.controlChange => 'CC',
    };
    return '$kind $number · ch $channel · $value';
  }

  @override
  String toString() => 'MidiMessage(${describe()})';
}
