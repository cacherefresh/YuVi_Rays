/// Soft takeover ("pick-up") for hardware knobs and faders.
///
/// When a physical knob doesn't match the on-screen value (after app start,
/// or after the on-screen control was moved), applying its value straight
/// away would make the sound jump. With pick-up, the knob is ignored until
/// it reaches the current value, either by landing within a tolerance of it
/// or by moving across it. From then on it controls the value directly,
/// until something else (e.g. the on-screen fader) changes the value again.
class SoftTakeover {
  final _engaged = <Object, bool>{};
  final _lastHardware = <Object, double>{};
  final _lastApplied = <Object, double>{};

  /// Whether the hardware value [incoming] should be applied to a control
  /// identified by [key] whose current value is [current].
  bool accept(Object key, double incoming, double current, double tolerance) {
    final previous = _lastHardware[key];
    _lastHardware[key] = incoming;

    // Someone else changed the value since we last set it: pick up again.
    final applied = _lastApplied[key];
    if (applied != null && (current - applied).abs() > 1e-9) {
      _engaged[key] = false;
    }

    var engaged = _engaged[key] ?? false;
    if (!engaged) {
      final close = (incoming - current).abs() <= tolerance;
      final crossed = previous != null &&
          (previous - current).sign != (incoming - current).sign;
      engaged = close || crossed;
    }
    _engaged[key] = engaged;
    if (engaged) _lastApplied[key] = incoming;
    return engaged;
  }

  /// Forget everything, e.g. when a device is unplugged.
  void reset() {
    _engaged.clear();
    _lastHardware.clear();
    _lastApplied.clear();
  }
}
