/// Decodes an Akai MPK Mini Mk II SysEx program dump (reply to
/// `F0 47 00 26 66 00 01 <program> F7`).
///
/// Layout from the 109-byte payload after the `F0 47 00 26 67 00 6D` header,
/// confirmed against the factory defaults read from Rob's unit:
///   [0] program, [1] pad channel (0-based), [2] key channel, [3] octave,
///   [20..83] 16 pads × (note, program change, CC, mode),
///   [84..107] 8 knobs × (CC, min, max), [108] transpose.
class MpkMiniMk2Program {
  MpkMiniMk2Program._(this.padChannel, this.padNotes, this.knobCcs);

  /// MIDI channel 1..16 the pads send on.
  final int padChannel;

  /// Note numbers for pads 1..16 (bank A pads 1-8, then bank B).
  final List<int> padNotes;

  /// CC numbers for knobs K1..K8.
  final List<int> knobCcs;

  static const _header = [0xF0, 0x47, 0x00, 0x26, 0x67, 0x00, 0x6D];

  factory MpkMiniMk2Program.parse(List<int> bytes) {
    for (var i = 0; i < _header.length; i++) {
      if (bytes[i] != _header[i]) {
        throw const FormatException('Not an MPK Mini Mk II program dump');
      }
    }
    final p = bytes.sublist(_header.length, bytes.length - 1); // drop F7
    if (p.length != 109) throw FormatException('Expected 109 bytes, got ${p.length}');
    return MpkMiniMk2Program._(
      p[1] + 1,
      [for (var i = 0; i < 16; i++) p[20 + i * 4]],
      [for (var i = 0; i < 8; i++) p[84 + i * 3]],
    );
  }

  /// Parses the hex text format used in test fixtures ('#' lines are comments).
  factory MpkMiniMk2Program.parseHexFile(String text) => MpkMiniMk2Program.parse([
        for (final line in text.split('\n'))
          if (!line.trimLeft().startsWith('#'))
            for (final h in line.trim().split(RegExp(r'\s+')))
              if (h.isNotEmpty) int.parse(h, radix: 16),
      ]);
}
