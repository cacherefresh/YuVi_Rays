import 'package:flutter/material.dart';
import 'package:yuvi_input/yuvi_input_web.dart';

import 'app_settings.dart';
import 'settings_dialog.dart';

/// Shows a one-time pop-up on a visitor's first load, pointing them to
/// Settings to connect a MIDI controller.
///
/// It is skipped when the browser has no Web MIDI (e.g. Safari) or MIDI is
/// already on. It is marked as seen as soon as it is shown, so it never
/// appears twice, however it is closed.
Future<void> maybeShowMidiHint(BuildContext context, AppSettings settings) async {
  if (settings.midiHintSeen || settings.midiEnabled || !MidiInputSource.isSupported) {
    return;
  }
  settings.markMidiHintSeen();

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF252527),
      icon: const Icon(Icons.piano, color: Color(0xFF00D4AA), size: 32),
      title: const Text('Got a MIDI controller?'),
      content: const SizedBox(
        width: 380,
        child: Text(
          'You can play the decks with a MIDI controller, such as an Akai '
          'MPK Mini. Plug it in over USB, then turn on "Enable MIDI '
          'controller" in Settings (the gear icon, top right).\n\n'
          'Keyboard shortcuts work too: [ ; . for Deck A and ] \' / for Deck B.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );

  if (openSettings == true && context.mounted) {
    await showSettingsDialog(context);
  }
}
