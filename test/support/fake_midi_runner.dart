import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yuvi_input/yuvi_input.dart';
import 'package:yuvi_rays/input/command_dispatcher.dart';

import 'fake_mixer.dart';

/// Replays a recorded or synthesized MIDI session through the real app path:
/// MIDI bytes → MidiMapper (profile, tap/hold) → CommandDispatcher (pick-up)
/// → mixer. Only the mixer is fake. Time is simulated, so a 10 s session
/// runs instantly and the same way every time.
class FakeMidiRunner {
  FakeMidiRunner({required this.profile, FakeMixer? mixer})
      : mixer = mixer ?? FakeMixer() {
    final dispatch = CommandDispatcher(this.mixer);
    _mapper = MidiMapper(profile, emit: (c) {
      commands.add(c);
      dispatch(c);
    }, timer: _createTimer);
  }

  final MidiProfile profile;
  final FakeMixer mixer;
  final commands = <MixerCommand>[];
  late final MidiMapper _mapper;

  Duration _now = Duration.zero;
  final _timers = <_SimTimer>[];

  static MidiProfile loadProfile(String path) =>
      MidiProfile.fromYaml(File(path).readAsStringSync());

  /// Plays every event of a session file, in time order.
  void playSessionFile(String path) {
    final doc = loadYaml(File(path).readAsStringSync()) as YamlMap;
    for (final e in (doc['events'] as YamlList?) ?? YamlList()) {
      sendAt(Duration(milliseconds: e['t'] as int), (e['bytes'] as YamlList).cast<int>());
    }
  }

  /// Advances simulated time to [at] (firing hold timers and moving
  /// playheads), then sends [bytes].
  void sendAt(Duration at, List<int> bytes) {
    advanceTo(at);
    _mapper.handleBytes(bytes);
  }

  void advanceTo(Duration target) {
    while (true) {
      final next = _timers.where((t) => t.active && t.at <= target).fold<_SimTimer?>(
          null, (a, t) => a == null || t.at < a.at ? t : a);
      final step = next?.at ?? target;
      _moveClock(step);
      if (next == null) break;
      next.active = false;
      next.callback();
    }
    _timers.removeWhere((t) => !t.active);
  }

  void _moveClock(Duration to) {
    final dt = to - _now;
    if (dt > Duration.zero) {
      for (final d in mixer.decks.values) {
        d.advance(dt);
      }
      _now = to;
    }
  }

  Timer _createTimer(Duration d, void Function() cb) {
    final t = _SimTimer(_now + d, cb);
    _timers.add(t);
    return t;
  }
}

class _SimTimer implements Timer {
  _SimTimer(this.at, this.callback);
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
