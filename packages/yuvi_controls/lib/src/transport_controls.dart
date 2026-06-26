import 'package:flutter/material.dart';
import 'package:yuvi_audio_engine/yuvi_audio_engine.dart';

class TransportControls extends StatelessWidget {
  const TransportControls({
    super.key,
    required this.state,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onSetCue,
    required this.onJumpCue,
    this.accentColor = const Color(0xFF00D4AA),
  });

  final DeckState state;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onSetCue;
  final VoidCallback onJumpCue;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TBtn(
          icon: Icons.skip_previous,
          tooltip: 'To Start',
          onTap: onStop,
          color: const Color(0xFF8E8E93),
        ),
        const SizedBox(width: 6),
        _TBtn(
          icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
          tooltip: state.isPlaying ? 'Pause' : 'Play',
          onTap: state.isPlaying ? onPause : onPlay,
          color: accentColor,
          size: 42,
        ),
        const SizedBox(width: 6),
        _TBtn(
          icon: Icons.stop,
          tooltip: 'Stop',
          onTap: onStop,
          color: const Color(0xFF8E8E93),
        ),
        const SizedBox(width: 12),
        _TBtn(
          label: 'CUE',
          tooltip: 'Set Cue Point',
          onTap: state.isLoaded ? onSetCue : null,
          color: const Color(0xFFFF9500),
        ),
        const SizedBox(width: 4),
        _TBtn(
          label: '►CUE',
          tooltip: 'Jump to Cue',
          onTap: state.isLoaded ? onJumpCue : null,
          color: const Color(0xFFFF9500),
        ),
        if (state.duration > 0) ...[
          const SizedBox(width: 12),
          Text(
            _formatTime(state.position * state.duration),
            style: TextStyle(
              color: accentColor,
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            ' / ${_formatTime(state.duration)}',
            style: const TextStyle(
              color: Color(0xFF636366),
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.toInt();
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _TBtn extends StatelessWidget {
  const _TBtn({
    this.icon,
    this.label,
    required this.onTap,
    required this.color,
    this.size = 34.0,
    this.tooltip,
  });

  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.35);

    Widget child;
    if (icon != null) {
      child = Icon(icon, color: effectiveColor, size: size * 0.55);
    } else {
      child = Text(
        label ?? '',
        style: TextStyle(
          color: effectiveColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );
    }

    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? effectiveColor.withValues(alpha: 0.4) : const Color(0xFF3A3A3C),
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
