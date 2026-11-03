import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';
import 'package:yuvi_controls/yuvi_controls.dart';
import 'package:yuvi_deck/yuvi_deck.dart';
import 'package:yuvi_midi_engine/yuvi_midi_engine.dart';

import '../providers/app_mode_provider.dart';
import '../providers/mixer_provider.dart';

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  List<PresetTrack> _presets = const [];
  bool _manifestLoaded = false;
  bool _midiRegistered = false;
  bool _auxPoppedOut = false;

  static const _auxAccent = Color(0xFF9F5AFB);

  // Use didChangeDependencies (not initState) so DefaultAssetBundle.of(context)
  // and Provider.of are guaranteed to be available. The guard flags prevent
  // repeated loads/registration.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_manifestLoaded) {
      _manifestLoaded = true;
      _loadManifest();
    }
    if (!_midiRegistered) {
      _midiRegistered = true;
      _registerMidiControls();
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

  /// One-time wiring from every mappable control to the MIDI-Learn engine.
  /// This is the sole place that connects [MidiLearnController] dispatch to
  /// [MixerProvider] — both are siblings in the provider tree, so neither
  /// can wire the other up at construction time.
  void _registerMidiControls() {
    final mixer = context.read<MixerProvider>();
    final midi = context.read<MidiLearnController>();

    midi.registerControl(MidiControlIds.deckAVolume, mixer.deckA.setVolume);
    midi.registerControl(MidiControlIds.deckAPlay, (v) {
      if (v <= 0) return;
      mixer.stateA.isPlaying ? mixer.deckA.pause() : mixer.deckA.play();
    });
    midi.registerControl(MidiControlIds.deckACue, (v) {
      if (v > 0) mixer.deckA.jumpToCue();
    });
    midi.registerControl(MidiControlIds.deckAStop, (v) {
      if (v > 0) mixer.deckA.stop();
    });

    midi.registerControl(MidiControlIds.deckBVolume, mixer.deckB.setVolume);
    midi.registerControl(MidiControlIds.deckBPlay, (v) {
      if (v <= 0) return;
      mixer.stateB.isPlaying ? mixer.deckB.pause() : mixer.deckB.play();
    });
    midi.registerControl(MidiControlIds.deckBCue, (v) {
      if (v > 0) mixer.deckB.jumpToCue();
    });
    midi.registerControl(MidiControlIds.deckBStop, (v) {
      if (v > 0) mixer.deckB.stop();
    });

    midi.registerControl(MidiControlIds.auxVolume, mixer.aux.setVolume);
    midi.registerControl(MidiControlIds.auxGain, mixer.aux.setGain);

    // The crossfader is where a Stokyo Kutter (or any hardware crossfader
    // wired as a MIDI position sensor) maps to — see DJ_INSTRUCTIONS.md.
    midi.registerControl(MidiControlIds.crossfader, mixer.setCrossfader);
  }

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();
    final appMode = context.watch<AppModeProvider>();
    final midi = context.watch<MidiLearnController>();

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
          IconButton(
            icon: const Icon(Icons.piano_outlined, size: 18),
            color: const Color(0xFF8E8E93),
            tooltip: 'MIDI mapping',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => MidiMapPanel(midi: midi),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Desktop Mode',
                  style: TextStyle(
                    color: appMode.desktopMode ? _auxAccent : const Color(0xFF636366),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: appMode.desktopMode,
                  activeThumbColor: _auxAccent,
                  onChanged: (_) => appMode.toggleDesktopMode(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFF00D4AA), size: 8),
                const SizedBox(width: 6),
                const Text(
                  'Web Audio API  •  Tone.js',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Decks (+ AUX channel, desktop mode only) ─────────────
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
                      const SizedBox(width: 6),
                      // ── Master VU meter ──────────────────────────────
                      SizedBox(
                        width: 44,
                        child: VuMeterWidget(
                          levelProvider: () => yuViDVS.getMasterLevel(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DeckWidget(
                          state: mixer.stateB,
                          controller: mixer.deckB,
                          accentColor: const Color(0xFFFF9500),
                          presetTracks: _presets,
                        ),
                      ),
                      if (appMode.desktopMode && !_auxPoppedOut) ...[
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 220,
                          child: AuxChannelWidget(
                            state: mixer.auxState,
                            controller: mixer.aux,
                            accentColor: _auxAccent,
                            showPopOutButton: true,
                            onPopOut: () => setState(() => _auxPoppedOut = true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Crossfader ──────────────────────────────────────────
              _CrossfaderBar(
                value: mixer.crossfader,
                onChanged: mixer.setCrossfader,
              ),

              // ── Audio Graph ───────────────────────────────────────────
              AudioGraphWidget(
                deckA: mixer.stateA,
                deckB: mixer.stateB,
              ),
            ],
          ),

          // ── Popped-out AUX/VST floating panel ──────────────────────
          if (appMode.desktopMode && _auxPoppedOut)
            FloatingPanel(
              title: 'AUX / VST — Channel 3',
              accentColor: _auxAccent,
              onDock: () => setState(() => _auxPoppedOut = false),
              child: AuxChannelWidget(
                state: mixer.auxState,
                controller: mixer.aux,
                accentColor: _auxAccent,
              ),
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
