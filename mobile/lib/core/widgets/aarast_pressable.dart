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
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.scale = 0.985,
    this.duration = const Duration(milliseconds: 120),
    this.haptic = true,
    this.clip = true,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final double scale;
  final Duration duration;
  final bool haptic;
  final bool clip;

  @override
  State<AarastPressable> createState() => _AarastPressableState();
}

class _AarastPressableState extends State<AarastPressable> {
  bool _pressed = false;
  bool _hasFocus = false;
  bool _showFocusHighlight = false;

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    onTap();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  void _handleFocusChange(bool focused) {
    if (_hasFocus == focused && (focused || !_pressed)) return;
    setState(() {
      _hasFocus = focused;
      if (!focused) _pressed = false;
    });
  }

  void _handleFocusHighlight(bool visible) {
    if (_showFocusHighlight == visible) return;
    setState(() => _showFocusHighlight = visible);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final radius = widget.borderRadius;
    final effectiveRadius = radius ?? BorderRadius.circular(20);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : widget.duration;
    final scaledChild = widget.clip
        ? ClipRRect(borderRadius: effectiveRadius, child: widget.child)
        : widget.child;

    final core = AnimatedScale(
      scale: _pressed ? widget.scale : 1.0,
      duration: duration,
      curve: Curves.easeOut,
      child: scaledChild,
    );

    final focusAwareCore = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      foregroundDecoration: BoxDecoration(
        borderRadius: effectiveRadius,
        border: _showFocusHighlight
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: core,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      focusable: enabled,
      focused: enabled ? _hasFocus : null,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: enabled ? _handleTap : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: _handleFocusChange,
        onShowFocusHighlight: _handleFocusHighlight,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: enabled ? _handleTap : null,
          child: focusAwareCore,
        ),
      ),
    );
  }
}
