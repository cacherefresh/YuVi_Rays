import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

import 'fader_widget.dart';
import 'knob_widget.dart';
import 'vu_meter_widget.dart';

/// Third mixer channel — no platter, just a gain knob + fader over a
/// virtual-audio-input strip (fed by a real VST via a virtual audio
/// cable) plus a placeholder for the native-desktop VST loader.
class AuxChannelWidget extends StatefulWidget {
  const AuxChannelWidget({
    super.key,
    required this.state,
    required this.controller,
    this.accentColor = const Color(0xFF9F5AFB),
    this.showPopOutButton = false,
    this.onPopOut,
  });

  final AuxState state;
  final AuxChannelController controller;
  final Color accentColor;
  final bool showPopOutButton;
  final VoidCallback? onPopOut;

  @override
  State<AuxChannelWidget> createState() => _AuxChannelWidgetState();
}

class _AuxChannelWidgetState extends State<AuxChannelWidget> {
  List<AudioInputDevice> _devices = const [];
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    _refreshDevices();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  Future<void> _refreshDevices() async {
    setState(() => _loadingDevices = true);
    final devices = await widget.controller.listInputDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loadingDevices = false;
    });
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
          Row(
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
                child: Icon(Icons.extension_outlined, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AUX / VST',
                  style: TextStyle(
                    color: Color(0xFFEBEBF0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (widget.showPopOutButton)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF8E8E93)),
                  tooltip: 'Pop out',
                  onPressed: widget.onPopOut,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInputPicker(color),
          const SizedBox(height: 8),
          _buildVstPlaceholder(color),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KnobWidget(
                  label: 'GAIN',
                  value: state.gain,
                  onChanged: widget.controller.setGain,
                  color: color,
                  size: 40,
                ),
                const SizedBox(width: 8),
                VuMeterWidget(
                  levelProvider: widget.controller.getLevel, // shares the master meter; per-channel metering is future work
                  label: 'LVL',
                ),
                const SizedBox(width: 8),
                FaderWidget(
                  value: state.volume,
                  onChanged: widget.controller.setVolume,
                  color: color,
                  height: 140,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPicker(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.mic_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: widget.state.selectedDeviceId,
                hint: Text(
                  _loadingDevices ? 'Loading inputs…' : 'Select input',
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                ),
                dropdownColor: const Color(0xFF2C2C2E),
                style: const TextStyle(color: Color(0xFFEBEBF0), fontSize: 11),
                items: _devices
                    .map((d) => DropdownMenuItem(value: d.id, child: Text(d.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (id) {
                  final device = _devices.firstWhere((d) => d.id == id);
                  widget.controller.selectInput(device);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF8E8E93)),
            tooltip: 'Refresh input devices',
            onPressed: _refreshDevices,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildVstPlaceholder(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.piano_outlined, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Native VST loading is a Desktop-app feature — see DJ_INSTRUCTIONS.md. '
              'Route a VST here today via a virtual audio cable (BlackHole/VB-Cable).',
              style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 9.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
