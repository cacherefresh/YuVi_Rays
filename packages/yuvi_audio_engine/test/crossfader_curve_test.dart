import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/src/crossfader_curve.dart';

void main() {
  test('full left plays only the left deck', () {
    final g = equalPowerCrossfade(0);
    expect(g.left, closeTo(1, 1e-9));
    expect(g.right, closeTo(0, 1e-9));
  });

  test('full right plays only the right deck', () {
    final g = equalPowerCrossfade(1);
    expect(g.left, closeTo(0, 1e-9));
    expect(g.right, closeTo(1, 1e-9));
  });

  test('centre is equal power (-3 dB each side)', () {
    final g = equalPowerCrossfade(0.5);
    expect(g.left, closeTo(g.right, 1e-9));
    expect(g.left * g.left + g.right * g.right, closeTo(1, 1e-9));
  });

  test('out-of-range input is clamped', () {
    expect(equalPowerCrossfade(-2).left, closeTo(1, 1e-9));
    expect(equalPowerCrossfade(5).right, closeTo(1, 1e-9));
  });
}
