/// A single incoming MIDI event, already parsed by the JS bridge.
class MidiMessage {
  const MidiMessage({
    required this.type,
    required this.channel,
    required this.number,
    required this.value,
  });

  factory MidiMessage.fromJson(Map<String, dynamic> json) {
    return MidiMessage(
      type: (json['type'] as String?) == 'note' ? MidiType.note : MidiType.cc,
      channel: (json['channel'] as num?)?.toInt() ?? 0,
      number: (json['number'] as num?)?.toInt() ?? 0,
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }

  final MidiType type;
  final int channel;
  final int number;

  /// Raw 0-127 MIDI value (velocity for notes, CC value for controllers).
  final int value;

  /// Normalized 0.0-1.0 value.
  double get normalized => (value / 127.0).clamp(0.0, 1.0);
}

enum MidiType { cc, note }
