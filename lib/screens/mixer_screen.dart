import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';
import 'package:yuvi_controls/yuvi_controls.dart';
import 'package:yuvi_deck/yuvi_deck.dart';

import '../providers/mixer_provider.dart';
import '../settings/app_settings.dart';
import '../settings/headphone_section.dart';
import '../settings/midi_hint_dialog.dart';
import '../settings/settings_dialog.dart';

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  List<PresetTrack> _presets = const [];
  bool _presetsLoaded = false;

  // Use didChangeDependencies (not initState) so DefaultAssetBundle.of(context)
  // is guaranteed to be available. The guard flag prevents repeated loads.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_presetsLoaded) {
      _presetsLoaded = true;
      _loadPresets();
      // First visit only: point people at Settings for MIDI controllers.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowMidiHint(context, context.read<AppSettings>());
      });
    }
  }

  /// Lists every audio file bundled from assets/royalty_free_audio/, using
  /// Flutter's own asset list. No hand-kept manifest: drop a file in the
  /// folder, rebuild, and it appears. The name shown is the file name.
  Future<void> _loadPresets() async {
    const dir = 'assets/royalty_free_audio/';
    final audio = RegExp(r'\.(mp3|m4a|aac|wav|ogg|flac)$', caseSensitive: false);
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
      final files = manifest
          .listAssets()
          .where((k) => k.startsWith(dir) && audio.hasMatch(k))
          .map((k) => k.substring(dir.length))
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final tracks = [
        for (final f in files) PresetTrack(name: f.replaceAll(audio, ''), file: f),
      ];
      if (mounted) setState(() => _presets = tracks);
    } catch (e) {
      debugPrint('[MixerScreen] could not list bundled audio: $e');
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
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings, color: Color(0xFF8E8E93), size: 20),
                  onPressed: () => showSettingsDialog(context),
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
                  const SizedBox(width: 6),
                  // ── Master section: VU meter, master fader, headphones ─
                  _MasterSection(mixer: mixer),
                  const SizedBox(width: 6),
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
            master: mixer.master,
          ),
        ],
      ),
    );
  }
}

class _MasterSection extends StatelessWidget {
  const _MasterSection({required this.mixer});

  final MixerProvider mixer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mixer.master,
      builder: (context, _) {
        final m = mixer.master;
        return SizedBox(
          width: 92,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 44,
                      child: VuMeterWidget(
                        levelProvider: () => yuViDVS.getMasterLevel(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Center(
                        child: FaderWidget(
                          value: m.masterVolume,
                          onChanged: mixer.setMasterVolume,
                          color: Colors.white,
                          label: 'MST',
                          width: 24,
                          height: 140,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Headphones: cue/master mix and level. Affect only the
              // headphone output, never the speakers.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Tooltip(
                    message: 'Headphone mix: left = cued decks, right = master',
                    child: KnobWidget(
                      label: 'MIX',
                      value: m.headphoneMix,
                      onChanged: mixer.setHeadphoneMix,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  KnobWidget(
                    label: 'PHONES',
                    value: m.headphoneVolume,
                    onChanged: mixer.setHeadphoneVolume,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              HeadphoneStatusChip(outputs: mixer.outputs),
            ],
          ),
        );
      },
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
