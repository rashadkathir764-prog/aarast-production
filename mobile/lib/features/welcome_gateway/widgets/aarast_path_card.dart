import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3_foundations.dart';

/// Visual priority for a welcome path. Every choice stays on the soft-white
/// product canvas; hierarchy comes from borders, tint, and typography.
enum AarastPathTone { hero, accent, quiet }

/// A path/role control shared by the welcome gateway.
///
/// Navigation choices use [selected] = null. Role choices pass a boolean.
/// The hero path (or the active role) gets a quiet selected surface without
/// turning the gateway into a stack of dark promotional cards.
class AarastPathCard extends StatefulWidget {
  const AarastPathCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = AarastPathTone.accent,
    this.selected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final AarastPathTone tone;
  final bool? selected;

  @override
  State<AarastPathCard> createState() => _AarastPathCardState();
}

class _AarastPathCardState extends State<AarastPathCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AarastV3Motion.quick,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 0.985,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  bool _hovered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selected != null;
    final selected = widget.selected ?? false;
    final featured =
        selected || (!hasSelection && widget.tone == AarastPathTone.hero);
    const foreground = AarastV3Color.ink;
    const secondary = AarastV3Color.textMuted;
    final accent = widget.tone == AarastPathTone.quiet
        ? AarastV3Color.mint
        : featured
        ? AarastV3Color.primary
        : AarastV3Color.cobalt;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        selected: hasSelection ? selected : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap();
          },
          onTapCancel: _controller.reverse,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: AarastV3Motion.standard,
              curve: AarastV3Motion.curve,
              constraints: const BoxConstraints(minHeight: 82),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: featured
                    ? AarastV3Color.primarySoft
                    : _hovered
                    ? AarastV3Color.paperQuiet
                    : AarastV3Color.paper,
                borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                border: Border.all(
                  color: featured
                      ? AarastV3Color.primary.withValues(alpha: .34)
                      : AarastV3Color.line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: featured
                          ? AarastV3Color.paper
                          : AarastV3Color.paperQuiet,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: featured
                            ? AarastV3Color.primary.withValues(alpha: .18)
                            : AarastV3Color.line,
                      ),
                    ),
                    child: Icon(widget.icon, color: accent, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: foreground,
                                fontFamily: AarastV3Type.displayFamily,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: secondary,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PathTrailing(
                    selected: widget.selected,
                    featured: featured,
                    accent: accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathTrailing extends StatelessWidget {
  const _PathTrailing({
    required this.selected,
    required this.featured,
    required this.accent,
  });

  final bool? selected;
  final bool featured;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return Icon(
        LucideIcons.arrowLeft,
        size: 20,
        color: featured ? AarastV3Color.primary : AarastV3Color.textFaint,
      );
    }
    if (selected!) {
      return const Icon(
        LucideIcons.checkCircle,
        size: 24,
        color: AarastV3Color.primary,
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
    );
  }
}
