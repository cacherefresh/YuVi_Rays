import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_input/yuvi_input_web.dart';

import '../input/input_controller.dart';
import 'app_settings.dart';
import 'midi_mapping_section.dart';

const _accent = Color(0xFF00D4AA);
const _muted = Color(0xFF8E8E93);

Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => MultiProvider(
      // Re-provide to the dialog route, which sits outside the screen's tree.
      providers: [
        ChangeNotifierProvider.value(value: context.read<AppSettings>()),
        Provider.value(value: context.read<InputController>()),
      ],
      child: const _SettingsDialog(),
    ),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final input = context.read<InputController>();
    final midi = input.midi;
    final registry = input.registry;

    return AlertDialog(
      backgroundColor: const Color(0xFF252527),
      title: const Text('Settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _accent,
                title: const Text('Enable MIDI controller'),
                subtitle: const Text(
                  'Chrome will ask for permission the first time.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                value: settings.midiEnabled,
                onChanged: MidiInputSource.isSupported
                    ? (v) => settings.midiEnabled = v
                    : null,
              ),
              if (midi == null)
                const Text('Loading MIDI profiles…', style: TextStyle(color: _muted))
              else
                ListenableBuilder(
                  listenable: midi.connection,
                  builder: (_, _) => _MidiStatusView(midi.connection),
                ),
              if (midi != null && registry != null) ...[
                const SizedBox(height: 16),
                MidiMappingSection(midi: midi, registry: registry),
              ],
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _accent,
                title: const Text('Prefer BPM from the MP3 tag'),
                subtitle: const Text(
                  'Off: use the BPM detected when a track loads. '
                  'Either source is used when the other is missing.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                value: settings.preferTagBpm,
                onChanged: (v) => settings.preferTagBpm = v,
              ),
              const Divider(height: 32),
              const Text('Keyboard', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const _KeyboardTable(),
              const SizedBox(height: 12),
              const Text(
                'Full hardware guide: DJ_SETUP_INSTRUCTIONS.md in the repository.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MidiStatusView extends StatelessWidget {
  const _MidiStatusView(this.c);

  final MidiConnectionState c;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (c.status) {
      MidiStatus.off => ('MIDI is off.', _muted),
      MidiStatus.requesting => ('Waiting for permission…', Colors.amber),
      MidiStatus.unsupported => ('MIDI is not supported in this browser. Use Chrome or Edge.', Colors.redAccent),
      MidiStatus.denied => ('Permission denied. Allow MIDI devices in Chrome\'s site settings, then reload.', Colors.redAccent),
      MidiStatus.noDevice => ('No MIDI device found. Plug one in.', Colors.amber),
      MidiStatus.connected => ('Connected', _accent),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: color)),
        for (final e in c.devices.entries)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('• ${e.key}  —  profile: ${e.value}', style: const TextStyle(fontSize: 12)),
          ),
        if (c.status == MidiStatus.connected) ...[
          const SizedBox(height: 8),
          Text(
            'Last MIDI message: ${c.lastMessage ?? '— move a control —'}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _muted),
          ),
        ],
      ],
    );
  }
}

class _KeyboardTable extends StatelessWidget {
  const _KeyboardTable();

  static const _rows = [
    ('Play / pause', '[', ']'),
    ('Jump to cue', ';', "'"),
    ('Set cue', 'Shift + ;', "Shift + '"),
    ('Stop', '.', '/'),
    ('Hot cues 1-4', '1 2 3 4', '7 8 9 0'),
    ('Clear a hot cue', 'Shift + 1-4', 'Shift + 7-0'),
  ];

  @override
  Widget build(BuildContext context) {
    TableRow row(String a, String b, String c, {bool header = false}) {
      final style = TextStyle(
        fontSize: 12,
        color: header ? _muted : null,
        fontFamily: header ? null : 'monospace',
      );
      return TableRow(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(a, style: style.copyWith(fontFamily: null))),
        Text(b, style: style),
        Text(c, style: style),
      ]);
    }

    return Table(
      columnWidths: const {0: FlexColumnWidth(2)},
      children: [
        row('', 'Deck A', 'Deck B', header: true),
        for (final r in _rows) row(r.$1, r.$2, r.$3),
      ],
    );
  }
}
