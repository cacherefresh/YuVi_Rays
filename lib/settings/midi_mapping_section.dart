import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:yuvi_input/yuvi_input_web.dart';

/// Settings → MIDI mapping: for each connected device, choose its profile,
/// export it as YAML, import an edited YAML, or reset to automatic.
class MidiMappingSection extends StatelessWidget {
  const MidiMappingSection({super.key, required this.midi, required this.registry});

  final MidiInputSource midi;
  final MidiProfileRegistry registry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: midi.connection,
      builder: (context, _) {
        final devices = midi.connection.devices.keys.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MIDI mapping', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (devices.isEmpty)
              const Text(
                'Connect a MIDI device and turn MIDI on to change its mapping.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
              )
            else
              for (final d in devices) _DeviceMapping(device: d, midi: midi, registry: registry),
          ],
        );
      },
    );
  }
}

class _DeviceMapping extends StatefulWidget {
  const _DeviceMapping({required this.device, required this.midi, required this.registry});

  final String device;
  final MidiInputSource midi;
  final MidiProfileRegistry registry;

  @override
  State<_DeviceMapping> createState() => _DeviceMappingState();
}

class _DeviceMappingState extends State<_DeviceMapping> {
  String? _message;
  bool _error = false;

  String get _device => widget.device;
  MidiProfileRegistry get _registry => widget.registry;

  void _changed(String message, {bool error = false}) {
    if (!error) widget.midi.refreshMappings();
    setState(() {
      _message = message;
      _error = error;
    });
  }

  void _choose(String? choice) {
    if (choice == null) return;
    if (choice == MidiProfileRegistry.custom) {
      _registry.chooseCustom(_device);
    } else {
      _registry.choose(_device, choice);
    }
    _changed('Now using: ${_registry.resolve(_device).name}');
  }

  void _export() {
    final profile = _registry.resolve(_device);
    final yaml = profile.toYaml();
    final blob = web.Blob(<JSAny>[yaml.toJS].toJS, web.BlobPropertyBag(type: 'application/x-yaml'));
    final url = web.URL.createObjectURL(blob);
    final fileName = '${profile.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.yaml';
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = fileName
      ..click();
    web.URL.revokeObjectURL(url);
    _changed('Downloaded $fileName');
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
      withData: true,
    );
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    try {
      final p = _registry.importCustom(_device, utf8.decode(bytes));
      _changed('Imported "${p.name}" for this device');
    } on FormatException catch (e) {
      _changed('Not imported: ${e.message}', error: true);
    }
  }

  void _reset() {
    _registry.reset(_device);
    _changed('Reset. Now using: ${_registry.resolve(_device).name}');
  }

  @override
  Widget build(BuildContext context) {
    final choice = _registry.choiceFor(_device);
    final auto = MidiProfile.select(_device, _registry.bundled, fallback: _registry.fallback);
    final hasCustom = _registry.customFor(_device) != null;
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: MidiProfileRegistry.automatic, child: Text('Automatic (${auto.name})')),
      for (final p in _registry.all) DropdownMenuItem(value: p.name, child: Text(p.name)),
      if (hasCustom)
        DropdownMenuItem(
          value: MidiProfileRegistry.custom,
          child: Text('Custom: ${_registry.customFor(_device)!.name}'),
        ),
    ];
    final value = items.any((i) => i.value == choice) ? choice : MidiProfileRegistry.automatic;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_device, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items,
            onChanged: _choose,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export'),
              ),
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Import'),
              ),
              TextButton(
                onPressed: choice == MidiProfileRegistry.automatic && !hasCustom ? null : _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
          if (_message != null)
            Text(
              _message!,
              style: TextStyle(fontSize: 12, color: _error ? Colors.redAccent : const Color(0xFF00D4AA)),
            ),
        ],
      ),
    );
  }
}
