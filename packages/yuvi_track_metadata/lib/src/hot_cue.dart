/// A hot cue: a saved position in a track, with an optional colour and label.
class HotCue {
  const HotCue({required this.position, this.colorRgb, this.label});

  /// Position from the start of the track.
  final Duration position;

  /// Colour as 0xRRGGBB, or null for the app's default slot colour.
  final int? colorRgb;

  /// Optional name, e.g. "Drop".
  final String? label;

  double get seconds => position.inMicroseconds / 1e6;

  @override
  bool operator ==(Object other) =>
      other is HotCue &&
      other.position == position &&
      other.colorRgb == colorRgb &&
      other.label == label;

  @override
  int get hashCode => Object.hash(position, colorRgb, label);

  @override
  String toString() => 'HotCue(${seconds.toStringAsFixed(3)} s'
      '${colorRgb == null ? '' : ', #${colorRgb!.toRadixString(16).padLeft(6, '0')}'}'
      '${label == null || label!.isEmpty ? '' : ', "$label"'})';
}
