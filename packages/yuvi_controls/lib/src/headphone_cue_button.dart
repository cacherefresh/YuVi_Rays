import 'package:flutter/material.dart';

/// Headphone cue (PFL) toggle for one deck, as on a DJ mixer channel.
/// Lit when the deck plays in the headphone mix.
class HeadphoneCueButton extends StatelessWidget {
  const HeadphoneCueButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.color = const Color(0xFF00D4AA),
    this.width = 40,
  });

  final bool active;
  final VoidCallback? onPressed;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Headphone cue (PFL): hear this deck in the headphones',
      child: Material(
        color: active ? color.withValues(alpha: 0.85) : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: Container(
            width: width,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: active ? 1 : 0.4)),
            ),
            child: Icon(
              Icons.headphones,
              size: 15,
              color: active ? const Color(0xFF1C1C1E) : color.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
