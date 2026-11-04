import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:yuvi_track_metadata/yuvi_track_metadata.dart';

// ── Builders for synthetic Serato data, following the documented format ──

List<int> _u32(int n) => [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF];

List<int> _entry(String name, List<int> data) => [...ascii.encode(name), 0, ..._u32(data.length), ...data];

List<int> _cue(int index, int ms, int rgb, String label) => _entry('CUE', [
      0, index, ..._u32(ms), 0, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, 0, 0,
      ...utf8.encode(label), 0,
    ]);

/// GEOB data exactly as Serato writes it: 01 01, base64 with a newline every
/// 72 chars and no '=' padding, then zero padding.
Uint8List _geobData(List<int> payload) {
  final b64 = base64.encode(payload).replaceAll('=', '');
  final lines = [for (var i = 0; i < b64.length; i += 72) b64.substring(i, (i + 72).clamp(0, b64.length))];
  return Uint8List.fromList([1, 1, ...ascii.encode(lines.join('\n')), 0, 0, 0, 0]);
}

List<int> _syncsafe(int n) => [(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F];

/// An ID3v2.4 tag with one Serato Markers2 GEOB frame, then MP3 audio.
Uint8List _mp3With(Uint8List geobData) {
  final body = [0, ...latin1.encode('application/octet-stream'), 0, 0, ...latin1.encode('Serato Markers2'), 0, ...geobData];
  final frame = [...ascii.encode('GEOB'), ..._syncsafe(body.length), 0, 0, ...body];
  return Uint8List.fromList([...ascii.encode('ID3'), 4, 0, 0, ..._syncsafe(frame.length), ...frame, 0xFF, 0xFB, 0x90, 0]);
}

void main() {
  final payload = [
    1, 1,
    ..._entry('COLOR', [0, 0xFF, 0xFF, 0xFF]),
    ..._cue(0, 1500, 0xCC0000, 'Intro'),
    ..._cue(2, 62250, 0x00CC00, ''),
    ..._entry('BPMLOCK', [0]),
    0,
  ];

  test('reads hot cues from an MP3 with a Serato Markers2 frame', () {
    final cues = SeratoMarkers.readHotCues(_mp3With(_geobData(payload)));
    expect(cues.keys, [0, 2]);
    expect(cues[0], const HotCue(position: Duration(milliseconds: 1500), colorRgb: 0xCC0000, label: 'Intro'));
    expect(cues[2]!.seconds, 62.25);
    expect(cues[2]!.label, isNull);
  });

  test('base64 with a stray length still decodes (Serato quirk)', () {
    final data = _geobData(payload);
    // Lengthen the base64 by one junk character before the zero padding.
    final i = data.indexOf(0, 2);
    final quirky = Uint8List.fromList([...data.sublist(0, i), 0x41, ...data.sublist(i)]);
    expect(SeratoMarkers.decodeGeobData(quirky).keys, [0, 2]);
  });

  test('UTF-8 cue names', () {
    final p = [1, 1, ..._cue(1, 10, 0x0000CC, 'Estribillo ñ'), 0];
    expect(SeratoMarkers.decodePayload(Uint8List.fromList(p))[1]!.label, 'Estribillo ñ');
  });

  test('no tag, no Serato frame, or garbage gives no cues', () {
    expect(SeratoMarkers.readHotCues(Uint8List.fromList([0, 0, 0, 0x18, ...ascii.encode('ftypmp41')])), isEmpty);
    expect(SeratoMarkers.decodeGeobData(Uint8List.fromList([1, 1, ...ascii.encode('!!!not base64!!!'), 0])), isEmpty);
    expect(SeratoMarkers.decodePayload(Uint8List.fromList([9, 9, 9])), isEmpty);
  });

  test('a truncated entry stops safely', () {
    final p = Uint8List.fromList(payload.sublist(0, payload.length - 10));
    expect(() => SeratoMarkers.decodePayload(p), returnsNormally);
  });

  test('GEOB frame fields', () {
    final tag = Id3v2Tag.parse(_mp3With(_geobData(payload)))!;
    final f = tag.geob('Serato Markers2')!;
    expect(f.mimeType, 'application/octet-stream');
    expect(f.data.sublist(0, 2), [1, 1]);
  });
}
