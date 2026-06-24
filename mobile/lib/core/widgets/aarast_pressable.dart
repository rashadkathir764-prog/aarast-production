import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium pressable wrapper used across the Aarast Dashboard and key cards.
///
/// Combines:
/// - Subtle scale feedback (0.985 on press) using [AnimatedScale]
/// - Light haptic feedback (`HapticFeedback.selectionClick`) on tap
/// - Opaque hit-testing so the entire bounding box is tappable
///
/// Use this anywhere a card or chip needs to feel tappable and premium.
class AarastPressable extends StatefulWidget {
  const AarastPressable({
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.scale = 0.985,
    this.duration = const Duration(milliseconds: 120),
    this.haptic = true,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final double scale;
  final Duration duration;
  final bool haptic;

  @override
  State<AarastPressable> createState() => _AarastPressableState();
}

class _AarastPressableState extends State<AarastPressable> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius;
    final core = AnimatedScale(
      scale: _pressed ? widget.scale : 1.0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.circular(20),
        child: widget.child,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!_pressed) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      onTap: _handleTap,
      child: core,
    );
  }
}
