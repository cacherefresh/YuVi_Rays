import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_controls/yuvi_controls.dart';
import 'package:yuvi_deck/yuvi_deck.dart';

import '../providers/mixer_provider.dart';

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  List<PresetTrack> _presets = const [];
  bool _manifestLoaded = false;

  // Use didChangeDependencies (not initState) so DefaultAssetBundle.of(context)
  // is guaranteed to be available. The guard flag prevents repeated loads.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_manifestLoaded) {
      _manifestLoaded = true;
      _loadManifest();
    }
  }

  Future<void> _loadManifest() async {
    try {
      final bundle = DefaultAssetBundle.of(context);
      final raw = await bundle.loadString('assets/royalty_free_audio/manifest.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tracks = (json['tracks'] as List? ?? [])
          .map((t) => PresetTrack(
                name: t['name'] as String,
                file: t['file'] as String,
              ))
          .toList();
      // Guard against the widget being disposed before the Future completes.
      if (mounted) setState(() => _presets = tracks);
    } catch (_) {
      // No manifest or empty — silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151517),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'YuVi Rays',
              style: TextStyle(
                color: Color(0xFF00D4AA),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'DVS',
              style: TextStyle(
                color: Color(0xFF636366),
                fontWeight: FontWeight.w400,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFF00D4AA), size: 8),
                const SizedBox(width: 6),
                Text(
                  'Web Audio API  •  Tone.js',
                  style: const TextStyle(color: Color(0xFF636366), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Decks ───────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DeckWidget(
                      state: mixer.stateA,
                      controller: mixer.deckA,
                      accentColor: const Color(0xFF00D4AA),
                      presetTracks: _presets,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DeckWidget(
                      state: mixer.stateB,
                      controller: mixer.deckB,
                      accentColor: const Color(0xFFFF9500),
                      presetTracks: _presets,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Crossfader ──────────────────────────────────────────────
          _CrossfaderBar(
            value: mixer.crossfader,
            onChanged: mixer.setCrossfader,
          ),

          // ── Audio Graph ─────────────────────────────────────────────
          AudioGraphWidget(
            deckA: mixer.stateA,
            deckB: mixer.stateB,
          ),
        ],
      ),
    );
  }
}

class _CrossfaderBar extends StatelessWidget {
  const _CrossfaderBar({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('A', style: TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF3A3A3C),
                inactiveTrackColor: const Color(0xFF3A3A3C),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                overlayColor: Colors.white12,
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
                label: value == 0.5 ? 'Center' : (value < 0.5 ? 'A' : 'B'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('B', style: TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
