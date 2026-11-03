import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:yuvi_track_metadata/yuvi_track_metadata.dart';

List<int> _syncsafe(int n) => [(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F];
List<int> _int32(int n) => [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF];

/// Builds a tag with one text frame, followed by fake audio bytes.
Uint8List _tag(int version, String id, List<int> body) {
  final frame = version == 2
      ? [...ascii.encode(id), (body.length >> 16) & 0xFF, (body.length >> 8) & 0xFF, body.length & 0xFF, ...body]
      : [...ascii.encode(id), ...(version == 4 ? _syncsafe(body.length) : _int32(body.length)), 0, 0, ...body];
  final padded = [...frame, ...List.filled(16, 0)];
  return Uint8List.fromList([
    ...ascii.encode('ID3'), version, 0, 0, ..._syncsafe(padded.length), ...padded,
    0xFF, 0xFB, 0x90, 0x00, // start of an MP3 frame
  ]);
}

void main() {
  test('v2.3 Latin-1 TBPM', () {
    expect(Id3v2Tag.parse(_tag(3, 'TBPM', [0, ...latin1.encode('128')]))!.bpm, 128);
  });

  test('v2.4 UTF-8 TBPM with decimals and a null terminator', () {
    final tag = Id3v2Tag.parse(_tag(4, 'TBPM', [3, ...utf8.encode('124.35'), 0]))!;
    expect(tag.majorVersion, 4);
    expect(tag.bpm, 124.35);
  });

  test('v2.3 UTF-16 with BOM', () {
    final le = [0xFF, 0xFE, for (final c in '96'.codeUnits) ...[c, 0]];
    expect(Id3v2Tag.parse(_tag(3, 'TBPM', [1, ...le]))!.bpm, 96);
  });

  test('v2.2 three-letter frame id', () {
    expect(Id3v2Tag.parse(_tag(2, 'TBP', [0, ...latin1.encode('140')]))!.bpm, 140);
  });

  test('other text frames', () {
    expect(Id3v2Tag.parse(_tag(3, 'TIT2', [3, ...utf8.encode('Español')]))!.text('TIT2'), 'Español');
  });

  test('missing or invalid BPM is null', () {
    expect(Id3v2Tag.parse(_tag(3, 'TIT2', [0, 65]))!.bpm, isNull);
    expect(Id3v2Tag.parse(_tag(3, 'TBPM', [0, ...latin1.encode('fast')]))!.bpm, isNull);
    expect(Id3v2Tag.parse(_tag(3, 'TBPM', [0, ...latin1.encode('0')]))!.bpm, isNull);
  });

  test('files without an ID3 tag return null', () {
    // An MP4 file, like Rob's test song: starts with an ftyp box.
    final mp4 = Uint8List.fromList([0, 0, 0, 0x18, ...ascii.encode('ftypmp41'), 0, 0, 0, 0]);
    expect(Id3v2Tag.parse(mp4), isNull);
    expect(Id3v2Tag.parse(Uint8List(4)), isNull);
  });

  test('a frame size past the end of the tag stops parsing safely', () {
    final bytes = _tag(3, 'TBPM', [0, ...latin1.encode('128')]);
    bytes[17] = 0x7F; // corrupt the frame size
    expect(() => Id3v2Tag.parse(bytes), returnsNormally);
  });
}
