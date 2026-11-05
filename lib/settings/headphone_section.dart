import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';

import 'app_settings.dart';
import 'headphone_status_text.dart';
import 'settings_dialog.dart';

const _muted = HeadphoneColors.muted;
const _bad = HeadphoneColors.bad;
const _warn = HeadphoneColors.warn;

/// Settings → Audio outputs: where the master (speakers) and the headphone
/// cue mix play.
class HeadphoneSection extends StatefulWidget {
  const HeadphoneSection({super.key, required this.outputs});

  final AudioOutputs outputs;

  @override
  State<HeadphoneSection> createState() => _HeadphoneSectionState();
}

class _HeadphoneSectionState extends State<HeadphoneSection> {
  List<AudioOutputDevice> _devices = const [];
  String? _defaultName; // the system default device's name
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
          // "Default" is offered as "System default" instead.
          _devices = devices.where((d) => d.id != 'default').toList();
        case OutputDevicesFailed(:final reason):
          _error = reason == 'NotAllowedError'
              ? 'Microphone permission was refused, so Chrome won\'t show the '
                  'device names. Allow it in the address bar\'s site settings.'
              : 'Could not list devices ($reason).';
      }
    });
  }

  AudioOutputDevice? _byId(String? id, String? fallbackName) => id == null
      ? null
      : _devices.where((d) => d.id == id).firstOrNull ??
          AudioOutputDevice(id: id, name: fallbackName ?? '');

  Future<void> _chooseMaster(String? id) async {
    final d = _byId(id, _outputs.masterDeviceName);
    context.read<AppSettings>().rememberMasterDevice(d?.id, d?.name);
    await _outputs.setMasterDevice(d);
  }

  Future<void> _choosePhones(String? id) async {
    final d = _byId(id, _outputs.headphoneDeviceName);
    context.read<AppSettings>().rememberHeadphoneDevice(d?.id, d?.name);
    await _outputs.setHeadphoneDevice(d);
  }

  String? _nameOf(String? id, String? fallback) => id == null
      ? null
      : (_devices.where((d) => d.id == id).firstOrNull?.name ?? fallback);

  List<DropdownMenuItem<String?>> _items({
    required String nullLabel,
    required String? chosen,
    required String? chosenName,
  }) =>
      [
        DropdownMenuItem(value: null, child: Text(nullLabel, overflow: TextOverflow.ellipsis)),
        for (final d in _devices)
          DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
        // Keep a remembered device visible even when it isn't plugged in.
        if (chosen != null && !_devices.any((d) => d.id == chosen))
          DropdownMenuItem(
            value: chosen,
            child: Text('${chosenName ?? 'Saved device'}  (not found)',
                overflow: TextOverflow.ellipsis),
          ),
      ];

  Widget _picker({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _outputs;
    const title = Text('Audio outputs', style: TextStyle(fontWeight: FontWeight.w700));
    if (!o.supported) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: 6),
          Text(
            'This browser can\'t send audio to a second device. Use Chrome or Edge.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      );
    }

    final masterOn = o.masterDeviceId == null ? _defaultName : _nameOf(o.masterDeviceId, o.masterDeviceName);
    final phonesOn = _nameOf(o.headphoneDeviceId, o.headphoneDeviceName);
    final sameDevice = phonesOn != null && masterOn != null && phonesOn == masterOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 4),
        const Text(
          'Send the master to your speakers and the headphone cue to your '
          'headphones. On a MacBook with headphones in the jack, Chrome lists '
          '"MacBook Pro Speakers" and "External Headphones" separately: pick '
          'the speakers for the master and the headphones for the cue. USB and '
          'Bluetooth devices work too.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _picker(
          label: 'Master',
          value: o.masterDeviceId,
          items: _items(
            nullLabel: _defaultName == null ? 'System default' : 'System default ($_defaultName)',
            chosen: o.masterDeviceId,
            chosenName: o.masterDeviceName,
          ),
          onChanged: o.masterSupported ? _chooseMaster : null,
        ),
        if (!o.masterSupported)
          const Text('This browser always plays the master on the system default.',
              style: TextStyle(color: _muted, fontSize: 11)),
        if (o.masterError != null)
          Text('Master output error: ${o.masterError}',
              style: const TextStyle(color: _bad, fontSize: 12)),
        _picker(
          label: 'Headphones',
          value: o.headphoneDeviceId,
          items: _items(
            nullLabel: 'Off',
            chosen: o.headphoneDeviceId,
            chosenName: o.headphoneDeviceName,
          ),
          onChanged: _choosePhones,
        ),
        if (sameDevice)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'The headphones and the master are on the same device, so you will '
              'hear both mixed together. Pick different devices.',
              style: TextStyle(color: _warn, fontSize: 12),
            ),
          ),
        if (_namesHidden && _error == null) ...[
          const SizedBox(height: 6),
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
          message: '$text\nClick to choose the output devices.',
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => showSettingsDialog(context),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                outputs.status == HeadphoneStatus.off ? Icons.headset_off : Icons.headphones,
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
