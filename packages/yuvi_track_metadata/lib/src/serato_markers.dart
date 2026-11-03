import 'dart:convert';
import 'dart:typed_data';

import 'hot_cue.dart';
import 'id3v2.dart';

/// Reads Serato DJ hot cues from an MP3's ID3 tag (the `Serato Markers2`
/// GEOB frame), without writing anything.
///
/// Format, as documented by the community (e.g. Holzhaus/serato-tags):
///
/// ```
/// GEOB data:  01 01  <base64 text, with newlines>  00 ...
/// decoded:    01 01  then entries until a 00 byte:
///   entry:    name (ASCII, 0-terminated)  length (uint32 BE)  data
///   CUE data: 00  index(u8)  position ms (uint32 BE)  00  R G B  00 00  name (UTF-8, 0-terminated)
/// ```
///
/// Serato has 8 hot cue slots (index 0-7). The older `Serato Markers_`
/// frame isn't read yet.
class SeratoMarkers {
  const SeratoMarkers._();

  static const frameDescription = 'Serato Markers2';

  /// Hot cues by slot index (0-7) from the MP3 [bytes]. Empty when the file
  /// has no ID3 tag, no Serato data, or the data can't be decoded.
  static Map<int, HotCue> readHotCues(Uint8List bytes) {
    final geob = Id3v2Tag.parse(bytes)?.geob(frameDescription);
    if (geob == null) return const {};
    return decodeGeobData(geob.data);
  }

  /// Decodes the data of a `Serato Markers2` GEOB frame.
  static Map<int, HotCue> decodeGeobData(Uint8List data) {
    final payload = _base64Payload(data);
    if (payload == null) return const {};
    return decodePayload(payload);
  }

  /// Decodes the binary payload (after base64), starting `01 01`.
  static Map<int, HotCue> decodePayload(Uint8List p) {
    if (p.length < 2 || p[0] != 1 || p[1] != 1) return const {};
    final cues = <int, HotCue>{};
    var pos = 2;
    while (pos < p.length && p[pos] != 0) {
      final nameEnd = p.indexOf(0, pos);
      if (nameEnd < 0 || nameEnd + 5 > p.length) break;
      final name = ascii.decode(p.sublist(pos, nameEnd), allowInvalid: true);
      final len = ByteData.sublistView(p, nameEnd + 1, nameEnd + 5).getUint32(0);
      final start = nameEnd + 5;
      if (start + len > p.length) break;
      if (name == 'CUE') {
        final cue = _cue(Uint8List.sublistView(p, start, start + len));
        if (cue != null) cues[cue.$1] = cue.$2;
      }
      pos = start + len;
    }
    return cues;
  }

  static (int, HotCue)? _cue(Uint8List d) {
    if (d.length < 12) return null;
    final index = d[1];
    final ms = ByteData.sublistView(d, 2, 6).getUint32(0);
    final rgb = (d[7] << 16) | (d[8] << 8) | d[9];
    final nameEnd = d.indexOf(0, 12);
    final label = utf8.decode(d.sublist(12, nameEnd < 0 ? d.length : nameEnd),
        allowMalformed: true);
    return (index, HotCue(position: Duration(milliseconds: ms), colorRgb: rgb, label: label.isEmpty ? null : label));
  }

  /// Serato's GEOB data is `01 01` + base64 with line breaks, then zero
  /// padding. Its base64 can also be missing padding or have one stray
  /// character, so fix that before decoding.
  static Uint8List? _base64Payload(Uint8List data) {
    if (data.length < 2 || data[0] != 1 || data[1] != 1) return null;
    final end = data.indexOf(0, 2);
    var text = latin1
        .decode(data.sublist(2, end < 0 ? data.length : end))
        .replaceAll(RegExp(r'\s'), '');
    switch (text.length % 4) {
      case 1:
        text += 'A==';
      case 2:
        text += '==';
      case 3:
        text += '=';
    }
    try {
      return base64.decode(text);
    } on FormatException {
      return null;
    }
  }
}
