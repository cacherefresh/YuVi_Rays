import 'package:flutter/material.dart';

/// Generic draggable overlay panel — used to let the AUX/VST channel "pop
/// out" and be moved anywhere on screen (some VST editors are large).
/// Meant to be placed as a `Stack` child positioned above the base layout.
class FloatingPanel extends StatefulWidget {
  const FloatingPanel({
    super.key,
    required this.title,
    required this.child,
    this.initialOffset = const Offset(80, 80),
    this.width = 280,
    this.height = 340,
    this.onDock,
    this.accentColor = const Color(0xFF9F5AFB),
  });

  final String title;
  final Widget child;
  final Offset initialOffset;
  final double width;
  final double height;
  final VoidCallback? onDock;
  final Color accentColor;

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  late Offset _offset = widget.initialOffset;

  void _clampToScreen(Size screenSize) {
    final maxX = (screenSize.width - widget.width).clamp(0.0, double.infinity);
    final maxY = (screenSize.height - widget.height).clamp(0.0, double.infinity);
    _offset = Offset(_offset.dx.clamp(0.0, maxX), _offset.dy.clamp(0.0, maxY));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    _clampToScreen(screenSize);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: widget.width,
      height: widget.height,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1C1C1E),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.accentColor.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onPanUpdate: (d) => setState(() {
                  _offset += d.delta;
                  _clampToScreen(screenSize);
                }),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator, size: 14, color: widget.accentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (widget.onDock != null)
                        IconButton(
                          icon: const Icon(Icons.close_fullscreen, size: 13, color: Color(0xFF8E8E93)),
                          tooltip: 'Dock',
                          onPressed: widget.onDock,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}
