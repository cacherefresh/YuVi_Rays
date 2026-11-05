import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

/// Listens directly to the two DeckState ChangeNotifiers so the graph
/// updates immediately whenever any EQ knob or fader moves — no reliance
/// on an external ListenableBuilder in the parent.
class AudioGraphWidget extends StatefulWidget {
  const AudioGraphWidget({
    super.key,
    required this.deckA,
    required this.deckB,
    this.master,
  });

  final DeckState deckA;
  final DeckState deckB;

  /// Optional master section. When given, the graph also shows the
  /// crossfader, master and headphone nodes.
  final MasterState? master;

  @override
  State<AudioGraphWidget> createState() => _AudioGraphWidgetState();
}

class _AudioGraphWidgetState extends State<AudioGraphWidget> {
  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.deckA.addListener(_rebuild);
    widget.deckB.addListener(_rebuild);
    widget.master?.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(AudioGraphWidget old) {
    super.didUpdateWidget(old);
    if (old.deckA != widget.deckA) {
      old.deckA.removeListener(_rebuild);
      widget.deckA.addListener(_rebuild);
    }
    if (old.deckB != widget.deckB) {
      old.deckB.removeListener(_rebuild);
      widget.deckB.addListener(_rebuild);
    }
    if (old.master != widget.master) {
      old.master?.removeListener(_rebuild);
      widget.master?.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.deckA.removeListener(_rebuild);
    widget.deckB.removeListener(_rebuild);
    widget.master?.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Color(0xFF3A3A3C))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Scale down instead of overflowing on narrow windows.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DeckChain(
              deck: widget.deckA,
              color: const Color(0xFF00D4AA),
              label: 'A',
              xfadeGain: _xfade?.left,
            ),
            const SizedBox(width: 8),
            const _Arrow(),
            const SizedBox(width: 8),
            _masterNodes(),
            const SizedBox(width: 8),
            const _Arrow(reverse: true),
            const SizedBox(width: 8),
            _DeckChain(
              deck: widget.deckB,
              color: const Color(0xFFFF9500),
              label: 'B',
              reverse: true,
              xfadeGain: _xfade?.right,
            ),
          ],
        ),
      ),
    );
  }
}

extension on _AudioGraphWidgetState {
  CrossfaderGains? get _xfade {
    final m = widget.master;
    return m == null ? null : equalPowerCrossfade(m.crossfader);
  }

  Widget _masterNodes() {
    final m = widget.master;
    if (m == null) {
      return const _Node(label: 'MASTER', color: Colors.white, bold: true);
    }
    // Speakers come straight off the master. The headphones get their own
    // mix: pre-fader cue of the cued decks, blended with the master (plan 007).
    final cued = [
      if (widget.deckA.headphoneCue) widget.deckA.id,
      if (widget.deckB.headphoneCue) widget.deckB.id,
    ];
    final mix = (m.headphoneMix * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Node(label: 'MASTER', color: Colors.white, bold: true, value: _DeckChain._volDb(m.masterVolume)),
        const Text('▼', style: TextStyle(color: Color(0xFF636366), fontSize: 8)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Node(label: 'SPEAKERS', color: Colors.white),
            const SizedBox(width: 6),
            _Node(
              label: 'PHONES',
              color: Colors.white,
              value: 'CUE ${cued.isEmpty ? '-' : cued.join('+')} · '
                  'MST $mix% · ${_DeckChain._volDb(m.headphoneVolume)}',
            ),
          ],
        ),
      ],
    );
  }
}

class _DeckChain extends StatelessWidget {
  const _DeckChain({
    required this.deck,
    required this.color,
    required this.label,
    this.reverse = false,
    this.xfadeGain,
  });

  final DeckState deck;
  final Color color;
  final String label;
  final bool reverse;

  /// Linear crossfader gain for this deck, or null to hide the node.
  final double? xfadeGain;

  @override
  Widget build(BuildContext context) {
    final nodes = [
      _Node(
        label: 'DECK $label',
        color: color,
        value: deck.isPlaying ? '▶' : (deck.isLoaded ? '■' : '○'),
      ),
      const _Arrow(),
      _Node(label: 'PITCH', color: color, value: _pitch(deck)),
      const _Arrow(),
      _Node(label: 'HI',  color: color, value: _eqDb(deck.highEQ)),
      const _Arrow(),
      _Node(label: 'MID', color: color, value: _eqDb(deck.midEQ)),
      const _Arrow(),
      _Node(label: 'LOW', color: color, value: _eqDb(deck.lowEQ)),
      const _Arrow(),
      _Node(label: 'VOL', color: color, value: _volDb(deck.volume)),
      if (xfadeGain != null) ...[
        const _Arrow(),
        _Node(label: 'X-FADE', color: color, value: _volDb(xfadeGain!)),
      ],
    ];
    return Row(children: reverse ? nodes.reversed.toList() : nodes);
  }

  /// Maps the -1..+1 EQ state value to a dB label using the same curve as
  /// the JS kill-EQ: full-left → kill, -1..0 → -40..0 dB, 0..+1 → 0..+6 dB.
  static String _eqDb(double v) {
    if (v <= -1.0) return 'kill';
    if (v < 0) {
      final db = (v * 40).round();
      return '${db}dB';
    }
    final db = (v * 6).round();
    return db == 0 ? '0dB' : '+${db}dB';
  }

  /// Pitch label in both units, e.g. `+4.4% +0.74st`.
  static String _pitch(DeckState d) {
    String signed(double v, int n) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(n)}';
    return '${signed(d.pitchPercent, 1)}% ${signed(d.pitchSemitones, 2)}st';
  }

  /// Converts normalised volume (0..1) to a dB label.
  /// 1.0 → 0dB, 0.5 → -6dB, ~0 → -∞
  static String _volDb(double v) {
    if (v <= 0.001) return '-∞';
    final db = (20 * math.log(v) / math.ln10).round();
    return db == 0 ? '0dB' : '${db}dB';
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.label, required this.color, this.value, this.bold = false});

  final String label;
  final Color color;
  final String? value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 8),
            ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({this.reverse = false});
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Text(
      reverse ? '◄' : '►',
      style: const TextStyle(color: Color(0xFF636366), fontSize: 10),
    );
  }
}
