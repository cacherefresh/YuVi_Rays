import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';

import 'app_settings.dart';
import 'headphone_status_text.dart';
import 'settings_dialog.dart';

const _muted = HeadphoneColors.muted;
const _bad = HeadphoneColors.bad;

/// Settings → Headphones: choose the output device for the headphone mix.
class HeadphoneSection extends StatefulWidget {
  const HeadphoneSection({super.key, required this.outputs});

  final AudioOutputs outputs;

  @override
  State<HeadphoneSection> createState() => _HeadphoneSectionState();
}

class _HeadphoneSectionState extends State<HeadphoneSection> {
  List<AudioOutputDevice> _devices = const [];
  String? _defaultName; // the device the speakers (system default) use
  String? _error;
  bool _namesHidden = true;
  bool _loading = false;
  late int _seenVersion = widget.outputs.devicesVersion;

  AudioOutputs get _outputs => widget.outputs;

  @override
  void initState() {
    super.initState();
    _outputs.addListener(_onOutputsChanged);
    _refresh(askPermission: false);
  }

  @override
  void dispose() {
    _outputs.removeListener(_onOutputsChanged);
    super.dispose();
  }

  void _onOutputsChanged() {
    // Re-list when devices are plugged in or out.
    if (_outputs.devicesVersion != _seenVersion) {
      _seenVersion = _outputs.devicesVersion;
      _refresh(askPermission: false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh({required bool askPermission}) async {
    setState(() => _loading = true);
    final result = await _outputs.list(askPermission: askPermission);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case OutputDevicesFound(:final devices):
          _error = null;
          _namesHidden = result.namesHidden;
          final def = devices.where((d) => d.id == 'default').firstOrNull;
          _defaultName = def?.name.replaceFirst(RegExp(r'^Default - '), '');
          // "Default" would play the headphone mix on the speakers.
          _devices = devices.where((d) => d.id != 'default').toList();
        case OutputDevicesFailed(:final reason):
          _error = reason == 'NotAllowedError'
              ? 'Microphone permission was refused, so Chrome won\'t show the '
                  'device names. Allow it in the address bar\'s site settings.'
              : 'Could not list devices ($reason).';
      }
    });
  }

  Future<void> _choose(AudioOutputDevice? device) async {
    context.read<AppSettings>().rememberHeadphoneDevice(device?.id, device?.name);
    await _outputs.setHeadphoneDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    final o = _outputs;
    final title = const Text('Headphones', style: TextStyle(fontWeight: FontWeight.w700));
    if (!o.supported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 6),
          const Text(
            'This browser can\'t send audio to a second device. Use Chrome or Edge.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      );
    }

    final chosen = o.headphoneDeviceId;
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Off')),
      for (final d in _devices)
        DropdownMenuItem(
          value: d.id,
          child: Text(
            d.name == _defaultName ? '${d.name}  (speakers)' : d.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      // Keep a remembered device visible even when it isn't plugged in.
      if (chosen != null && !_devices.any((d) => d.id == chosen))
        DropdownMenuItem(
          value: chosen,
          child: Text('${o.headphoneDeviceName ?? 'Saved device'}  (not found)',
              overflow: TextOverflow.ellipsis),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 4),
        const Text(
          'The speakers play the master on your default output. Choose a second '
          'device for the headphone cue: a USB audio interface, USB or Bluetooth '
          'headphones, or a display. A MacBook\'s headphone jack is the same '
          'device as its speakers, so it can\'t be used for this.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: chosen,
                items: items,
                onChanged: (id) => _choose(id == null
                    ? null
                    : _devices.where((d) => d.id == id).firstOrNull ??
                        AudioOutputDevice(id: id, name: o.headphoneDeviceName ?? '')),
              ),
            ),
            IconButton(
              tooltip: 'Find devices again',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _loading ? null : () => _refresh(askPermission: true),
            ),
          ],
        ),
        if (_namesHidden && _error == null) ...[
          const SizedBox(height: 4),
          const Text(
            'Chrome shows device names only after you allow microphone access. '
            'YuVi Rays turns the microphone off straight away and records nothing.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _refresh(askPermission: true),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Show my output devices'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: _bad, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        _StatusLine(outputs: o),
        const SizedBox(height: 4),
        const Text(
          'The headphones run slightly behind the speakers (tens of ms). '
          'Bluetooth adds 150-300 ms, which makes beat matching by ear hard.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.outputs});

  final AudioOutputs outputs;

  @override
  Widget build(BuildContext context) {
    final (text, color) = describeHeadphoneStatus(outputs);
    return Row(
      children: [
        Icon(Icons.headphones, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
      ],
    );
  }
}

/// Small headphone status indicator for the master section. Opens Settings.
class HeadphoneStatusChip extends StatelessWidget {
  const HeadphoneStatusChip({super.key, required this.outputs});

  final AudioOutputs outputs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: outputs,
      builder: (context, _) {
        final (text, color) = describeHeadphoneStatus(outputs);
        return Tooltip(
          message: '$text\nClick to choose the headphone device.',
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => showSettingsDialog(context),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                outputs.status == HeadphoneStatus.off
                    ? Icons.headset_off
                    : Icons.headphones,
                size: 16,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}
