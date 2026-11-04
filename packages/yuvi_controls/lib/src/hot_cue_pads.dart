import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

/// A row of hot cue buttons, Serato style.
///
/// An empty slot shows its number in grey; pressing it sets the hot cue.
/// A set slot is filled with the cue's colour; pressing it jumps there.
/// Shift + click clears a slot.
class HotCuePads extends StatelessWidget {
  const HotCuePads({
    super.key,
    required this.cues,
    required this.onTrigger,
    required this.onClear,
    this.enabled = true,
  });

  final List<HotCue?> cues;
  final ValueChanged<int> onTrigger;
  final ValueChanged<int> onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, cue) in cues.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          _HotCueButton(
            index: i,
            cue: cue,
            enabled: enabled,
            onTap: () => HardwareKeyboard.instance.isShiftPressed ? onClear(i) : onTrigger(i),
          ),
        ],
      ],
    );
  }
}

class _HotCueButton extends StatelessWidget {
  const _HotCueButton({
    required this.index,
    required this.cue,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final HotCue? cue;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final set = cue != null;
    final color = Color(0xFF000000 | (cue?.colorRgb ?? DeckState.defaultHotCueColors[index]));
    final tooltip = set
        ? 'Hot cue ${index + 1}: ${_time(cue!.seconds)}${cue!.label == null ? '' : ' "${cue!.label}"'}'
            '\nClick to jump, Shift + click to clear'
        : 'Hot cue ${index + 1}: empty. Click to set it here';
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 40,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: set ? color : const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: set ? color : color.withValues(alpha: 0.45)),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: set ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  static String _time(double s) {
    final m = s ~/ 60;
    final sec = s - m * 60;
    return '$m:${sec.toStringAsFixed(2).padLeft(5, '0')}';
  }
}
