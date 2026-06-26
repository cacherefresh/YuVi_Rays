import 'dart:js_interop';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';
import 'package:yuvi_controls/yuvi_controls.dart';
import 'package:yuvi_waveform/yuvi_waveform.dart';

class DeckWidget extends StatefulWidget {
  const DeckWidget({
    super.key,
    required this.state,
    required this.controller,
    required this.accentColor,
    this.presetTracks = const [],
  });

  final DeckState state;
  final DeckAudioController controller;
  final Color accentColor;
  final List<PresetTrack> presetTracks;

  @override
  State<DeckWidget> createState() => _DeckWidgetState();
}

class _DeckWidgetState extends State<DeckWidget> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
  }

  @override
  void didUpdateWidget(DeckWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onStateChange);
      widget.state.addListener(_onStateChange);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'm4a'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final blobParts = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'audio/mpeg'));
    final url = web.URL.createObjectURL(blob);
    widget.controller.loadUrl(url, trackName: file.name);
  }

  Future<void> _loadPreset(PresetTrack track) async {
    widget.controller.loadUrl(
      'assets/royalty_free_audio/${track.file}',
      trackName: track.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final color = widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252527),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Track bar ──────────────────────────────────────────────
          _buildTrackBar(state, color),
          const SizedBox(height: 6),

          // ── Waveform strip ─────────────────────────────────────────
          WaveformStripWidget(
            state: state,
            accentColor: color,
            onSeek: widget.controller.seek,
          ),
          const SizedBox(height: 8),

          // ── Main controls ──────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // EQ column (highs / mids / lows only)
                _buildEQColumn(state, color),
                const SizedBox(width: 10),

                // Turntable (flexible center)
                Expanded(
                  child: TurntableWaveformWidget(
                    state: state,
                    accentColor: color,
                    onSeek: widget.controller.seek,
                  ),
                ),
                const SizedBox(width: 10),

                // Volume fader
                FaderWidget(
                  value: state.volume,
                  onChanged: widget.controller.setVolume,
                  color: color,
                  height: 160,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Pitch fader (horizontal, left → right) ─────────────────
          PitchFaderWidget(
            value: state.pitch,
            onChanged: widget.controller.setPitch,
            color: color.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 8),

          // ── Transport ──────────────────────────────────────────────
          ListenableBuilder(
            listenable: state,
            builder: (_, _) => TransportControls(
              state: state,
              onPlay: widget.controller.play,
              onPause: widget.controller.pause,
              onStop: widget.controller.stop,
              onSetCue: widget.controller.setCuePoint,
              onJumpCue: widget.controller.jumpToCue,
              accentColor: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackBar(DeckState state, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            state.id,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.trackName ?? 'No track loaded',
            style: TextStyle(
              color: state.trackName != null
                  ? const Color(0xFFEBEBF0)
                  : const Color(0xFF636366),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (widget.presetTracks.isNotEmpty)
          PopupMenuButton<PresetTrack>(
            icon: Icon(Icons.library_music_outlined, color: color, size: 18),
            tooltip: 'Load preset track',
            color: const Color(0xFF2C2C2E),
            onSelected: _loadPreset,
            itemBuilder: (_) => widget.presetTracks
                .map((t) => PopupMenuItem(
                      value: t,
                      child: Text(t.name, style: const TextStyle(color: Color(0xFFEBEBF0), fontSize: 13)),
                    ))
                .toList(),
          ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: _pickFile,
          icon: Icon(Icons.folder_open, size: 16, color: color),
          label: Text('LOAD', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            backgroundColor: color.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildEQColumn(DeckState state, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        KnobWidget(
          label: 'HIGH',
          value: (state.highEQ + 1) / 2,
          onChanged: (v) => widget.controller.setEQ('high', v * 2 - 1),
          color: color,
          size: 44,
        ),
        KnobWidget(
          label: 'MID',
          value: (state.midEQ + 1) / 2,
          onChanged: (v) => widget.controller.setEQ('mid', v * 2 - 1),
          color: color,
          size: 44,
        ),
        KnobWidget(
          label: 'LOW',
          value: (state.lowEQ + 1) / 2,
          onChanged: (v) => widget.controller.setEQ('low', v * 2 - 1),
          color: color,
          size: 44,
        ),
      ],
    );
  }
}

class PresetTrack {
  const PresetTrack({required this.name, required this.file});
  final String name;
  final String file;
}
