import 'dart:convert';
import 'dart:typed_data';

/// A parsed ID3v2 tag from the start of an MP3 file.
///
/// Supports ID3v2.2, v2.3 and v2.4 text frames. Tags with the whole-tag
/// unsynchronisation flag are rare and not decoded.
class Id3v2Tag {
  Id3v2Tag._(this.majorVersion, this._frames);

  /// 2, 3 or 4.
  final int majorVersion;

  /// Frame id → every frame body with that id, in file order. Some frames,
  /// such as GEOB, appear several times.
  final Map<String, List<Uint8List>> _frames;

  /// Parses the tag at the start of [bytes]. Returns null when there is no
  /// ID3v2 tag (for example a WAV or MP4 file), or it is unreadable.
  static Id3v2Tag? parse(Uint8List bytes) {
    if (bytes.length < 10 || bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
      return null; // no "ID3"
    }
    final version = bytes[3];
    if (version < 2 || version > 4) return null;
    final flags = bytes[5];
    if (flags & 0x80 != 0) return null; // unsynchronised tag: not supported
    final tagSize = _syncsafe(bytes, 6);
    final end = (10 + tagSize).clamp(0, bytes.length);

    var pos = 10;
    if (flags & 0x40 != 0 && version >= 3) {
      // Extended header: v2.4 size is syncsafe and includes itself;
      // v2.3 size excludes its own 4 size bytes.
      pos += version == 4 ? _syncsafe(bytes, pos) : _int32(bytes, pos) + 4;
    }

    final idLen = version == 2 ? 3 : 4;
    final headerLen = version == 2 ? 6 : 10;
    final frames = <String, List<Uint8List>>{};
    while (pos + headerLen <= end) {
      if (bytes[pos] == 0) break; // padding
      final id = ascii.decode(bytes.sublist(pos, pos + idLen), allowInvalid: true);
      final size = switch (version) {
        2 => (bytes[pos + 3] << 16) | (bytes[pos + 4] << 8) | bytes[pos + 5],
        3 => _int32(bytes, pos + 4),
        _ => _syncsafe(bytes, pos + 4),
      };
      final start = pos + headerLen;
      if (size <= 0 || start + size > end) break;
      (frames[id] ??= []).add(Uint8List.sublistView(bytes, start, start + size));
      pos = start + size;
    }
    return Id3v2Tag._(version, frames);
  }

  /// The text of a text frame such as `TBPM`, `TIT2` or `TPE1`.
  /// Use the 4-letter v2.3/v2.4 id; v2.2 ids are mapped automatically.
  String? text(String frameId) {
    final raw = (_frames[frameId] ?? _frames[_v22Ids[frameId]])?.first;
    if (raw == null || raw.isEmpty) return null;
    final body = raw.sublist(1);
    final s = switch (raw[0]) {
      0 => latin1.decode(body),
      1 => _utf16(body, bigEndian: null),
      2 => _utf16(body, bigEndian: true),
      3 => utf8.decode(body, allowMalformed: true),
      _ => null,
    };
    // Text can be null-terminated or hold several null-separated values.
    return s?.split('\u0000').first.trim();
  }

  /// Beats per minute from the `TBPM` frame, or null when absent or invalid.
  double? get bpm {
    final t = text('TBPM');
    final v = t == null ? null : double.tryParse(t.replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  /// Every GEOB (general encapsulated object) frame. DJ software such as
  /// Serato stores cue points and beat grids in these.
  List<GeobFrame> get geobFrames => [
        for (final raw in _frames['GEOB'] ?? _frames['GEO'] ?? const <Uint8List>[])
          ?GeobFrame._parse(raw),
      ];

  /// The GEOB frame with this [description], e.g. `Serato Markers2`.
  GeobFrame? geob(String description) {
    for (final f in geobFrames) {
      if (f.description == description) return f;
    }
    return null;
  }

  static const _v22Ids = {'TBPM': 'TBP', 'TIT2': 'TT2', 'TPE1': 'TP1', 'TALB': 'TAL'};

  static int _syncsafe(Uint8List b, int i) =>
      ((b[i] & 0x7F) << 21) | ((b[i + 1] & 0x7F) << 14) | ((b[i + 2] & 0x7F) << 7) | (b[i + 3] & 0x7F);

  static int _int32(Uint8List b, int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

  static String _utf16(Uint8List b, {required bool? bigEndian}) {
    var start = 0;
    var be = bigEndian ?? true;
    if (bigEndian == null && b.length >= 2) {
      if (b[0] == 0xFF && b[1] == 0xFE) {
        be = false;
        start = 2;
      } else if (b[0] == 0xFE && b[1] == 0xFF) {
        start = 2;
      }
    }
    final units = <int>[];
    for (var i = start; i + 1 < b.length; i += 2) {
      units.add(be ? (b[i] << 8) | b[i + 1] : (b[i + 1] << 8) | b[i]);
    }
    return String.fromCharCodes(units);
  }
}

/// A GEOB frame: an embedded binary object with a MIME type, file name and
/// description, followed by the raw data.
class GeobFrame {
  const GeobFrame(this.mimeType, this.fileName, this.description, this.data);

  final String mimeType;
  final String fileName;
  final String description;
  final Uint8List data;

  static GeobFrame? _parse(Uint8List raw) {
    if (raw.isEmpty) return null;
    final encoding = raw[0];
    final wide = encoding == 1 || encoding == 2; // UTF-16: 2-byte terminators
    var pos = 1;

    // MIME type is always Latin-1, ending in a single 0.
    final mimeEnd = raw.indexOf(0, pos);
    if (mimeEnd < 0) return null;
    final mime = latin1.decode(raw.sublist(pos, mimeEnd));
    pos = mimeEnd + 1;

    String? readText() {
      final end = _terminator(raw, pos, wide);
      if (end < 0) return null;
      final body = raw.sublist(pos, end);
      pos = end + (wide ? 2 : 1);
      return switch (encoding) {
        0 => latin1.decode(body),
        1 => Id3v2Tag._utf16(body, bigEndian: null),
        2 => Id3v2Tag._utf16(body, bigEndian: true),
        _ => utf8.decode(body, allowMalformed: true),
      };
    }

    final fileName = readText();
    final description = readText();
    if (fileName == null || description == null) return null;
    return GeobFrame(mime, fileName, description, Uint8List.sublistView(raw, pos));
  }

  static int _terminator(Uint8List b, int from, bool wide) {
    if (!wide) return b.indexOf(0, from);
    for (var i = from; i + 1 < b.length; i += 2) {
      if (b[i] == 0 && b[i + 1] == 0) return i;
    }
    return -1;
  }
}

