import 'package:flutter/material.dart';
import 'package:yuvi_midi_engine/yuvi_midi_engine.dart';

/// Lists every mappable control with its current MIDI mapping and a
/// "Learn" button, plus one-tap presets for the Akai MPK Mini and
/// MPD218/226. This is the UI for the MIDI-Learn engine — see
/// [MidiLearnController] for the underlying logic.
class MidiMapPanel extends StatelessWidget {
  const MidiMapPanel({super.key, required this.midi});

  final MidiLearnController midi;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: ListenableBuilder(
          listenable: midi,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.piano, color: Color(0xFF00D4AA), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MIDI Mapping',
                        style: TextStyle(color: Color(0xFFEBEBF0), fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8E8E93), size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (!midi.isSupported)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Web MIDI API isn\'t supported in this browser — use Chrome, Edge, or Opera.',
                      style: TextStyle(color: Color(0xFFFF9500), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetButton(context, 'Akai MPK Mini', akaiMpkMiniPreset),
                    _presetButton(context, 'Akai MPD218/226', akaiMpd218Preset),
                    TextButton(
                      onPressed: () {
                        for (final id in List.of(midi.mappings.keys)) {
                          midi.clearMapping(id);
                        }
                      },
                      child: const Text('Clear all', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF3A3A3C), height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: MidiControlIds.all.length,
                    separatorBuilder: (_, _) => const Divider(color: Color(0xFF2C2C2E), height: 1),
                    itemBuilder: (context, i) => _controlRow(context, MidiControlIds.all[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetButton(BuildContext context, String label, List<MidiMapping> preset) {
    return OutlinedButton(
      onPressed: () => midi.applyPreset(preset),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00D4AA),
        side: const BorderSide(color: Color(0xFF00D4AA)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _controlRow(BuildContext context, String controlId) {
    final mapping = midi.mappings[controlId];
    final learning = midi.learningControlId == controlId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              MidiControlIds.label(controlId),
              style: const TextStyle(color: Color(0xFFEBEBF0), fontSize: 12.5),
            ),
          ),
          Text(
            learning
                ? 'Listening…'
                : mapping == null
                    ? 'Unmapped'
                    : '${mapping.type == MidiType.cc ? 'CC' : 'Note'} ${mapping.number}'
                        '${mapping.channel != null ? ' Ch${mapping.channel! + 1}' : ''}',
            style: TextStyle(
              color: learning
                  ? const Color(0xFF00D4AA)
                  : mapping == null
                      ? const Color(0xFF636366)
                      : const Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: learning ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: OutlinedButton(
              onPressed: () => learning ? midi.cancelLearn() : midi.startLearn(controlId),
              style: OutlinedButton.styleFrom(
                foregroundColor: learning ? const Color(0xFFFF9500) : const Color(0xFF8E8E93),
                side: BorderSide(color: learning ? const Color(0xFFFF9500) : const Color(0xFF3A3A3C)),
                padding: const EdgeInsets.symmetric(vertical: 2),
                minimumSize: Size.zero,
              ),
              child: Text(learning ? 'Cancel' : 'Learn', style: const TextStyle(fontSize: 10.5)),
            ),
          ),
        ],
      ),
    );
  }
}
