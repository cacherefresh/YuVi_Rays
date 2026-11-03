import 'dart:async';

/// A manual clock for testing hold gestures without real waiting.
/// Pass [create] as a `TimerFactory`, then call [advance].
class FakeTimers {
  Duration now = Duration.zero;
  final _pending = <_FakeTimer>[];

  Timer create(Duration d, void Function() callback) {
    final t = _FakeTimer(now + d, callback);
    _pending.add(t);
    return t;
  }

  void advance(Duration d) {
    now += d;
    final due = _pending.where((t) => t.active && t.at <= now).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    for (final t in due) {
      t.active = false;
      t.callback();
    }
    _pending.removeWhere((t) => !t.active);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.at, this.callback);
  final Duration at;
  final void Function() callback;
  bool active = true;

  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => 0;
}
