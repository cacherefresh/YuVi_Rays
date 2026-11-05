import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';

/// Headphone status colours, shared by Settings and the master section.
abstract final class HeadphoneColors {
  static const ok = Color(0xFF00D4AA);
  static const muted = Color(0xFF8E8E93);
  static const warn = Color(0xFFFF9F0A);
  static const bad = Color(0xFFFF453A);
}

/// Short status text and colour for the headphone output.
/// Pure (no browser code), so it is unit tested on the VM.
(String, Color) describeHeadphoneStatus(AudioOutputs o) {
  final name = o.headphoneDeviceName;
  final on = (name == null || name.isEmpty) ? 'the chosen device' : name;
  return switch (o.status) {
    HeadphoneStatus.off => ('Headphones off', HeadphoneColors.muted),
    HeadphoneStatus.connecting => ('Connecting to $on…', HeadphoneColors.muted),
    HeadphoneStatus.playing => ('Playing on $on', HeadphoneColors.ok),
    HeadphoneStatus.waitingForClick =>
      ('Click anywhere to start the headphones on $on', HeadphoneColors.warn),
    HeadphoneStatus.lost => ('$on was unplugged. Plays again when it\'s back.', HeadphoneColors.warn),
    HeadphoneStatus.error =>
      ('Headphones error: ${o.statusMessage ?? 'unknown'}', HeadphoneColors.bad),
    HeadphoneStatus.unsupported => ('Not supported in this browser', HeadphoneColors.muted),
  };
}
