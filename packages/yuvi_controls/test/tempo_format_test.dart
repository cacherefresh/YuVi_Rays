import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_controls/src/pitch_fader_widget.dart';

void main() {
  test('tempo is 3 digits and 2 decimals', () {
    expect(PitchFaderWidget.formatTempo(124.354), '124.35');
    expect(PitchFaderWidget.formatTempo(98.2), '098.20');
    expect(PitchFaderWidget.formatTempo(150), '150.00');
  });

  test('unknown tempo shows dashes', () {
    expect(PitchFaderWidget.formatTempo(null), '---.--');
    expect(PitchFaderWidget.formatTempo(double.nan), '---.--');
  });

  test('tempo colour is purple at 75% opacity', () {
    expect(PitchFaderWidget.tempoColor.a, closeTo(0.75, 0.01));
  });
}
