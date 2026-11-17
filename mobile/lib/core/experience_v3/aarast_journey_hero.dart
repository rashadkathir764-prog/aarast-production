import 'package:flutter/material.dart';

import 'aarast_journey.dart';
import 'aarast_journey_moment.dart' show JourneyQamariyaPainter;
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// The plan's hero, the home's own (b01, b02): on the plan's colour, deep at
/// the far top corner (D45, the one gradient D3 allows), the qamariya window
/// and the gypsum frieze; the big figure beside its line and a smaller line
/// under it, an optional saffron [tag] on the row, and a [footer] under them
/// (the home's five moments, a tab's bar). Rashad 2026-11-17: the tasks, the
/// guests and the money's summary wear it exactly as the home does, the same
/// look and the same size; so do the provider's home, requests and calendar.
class JourneyPlanHero extends StatelessWidget {
  const JourneyPlanHero({
    required this.figure,
    required this.title,
    this.footer,
    this.subtitle,
    this.tag,
    this.onTap,
    this.semanticLabel,
    this.figureKey,
    super.key,
  });

  /// The figure's own key, for a screen that reads it.
  final Key? figureKey;

  /// The big figure in the home's 52 point («13»، «1.5»، «86»); null where
  /// Arabic says the count in its word («مهمتين»، «يومين»), as the home does
  /// for one and two days.
  final String? figure;

  /// Its line beside it, bold («يوم على عرسك»، «مليون ر.ي باقي عليك»).
  final String title;

  /// A quieter line under the title.
  final String? subtitle;

  /// The saffron tag on the figure's row, as the home's moment.
  final Widget? tag;

  /// Under the row: the home's moments, a tab's bar; none where nothing
  /// true fills it (the provider's waiting requests).
  final Widget? footer;
  final VoidCallback? onTap;

  /// What a screen reader hears for the whole hero.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final card = JourneyBox(
      color: context.accent.primary,
      radius: AarastV3Radius.feature,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topEnd,
              end: AlignmentDirectional.bottomStart,
              colors: [context.accent.primaryDark, context.accent.primary],
            ),
          ),
          child: CustomPaint(
            painter: JourneyQamariyaPainter(
              alpha: 0.10,
              centreX: rtl ? 0.12 : 0.88,
              frieze: true,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AarastV3Space.x4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // As the home: the tag sits on the figure's row, and moves
                  // above the footer on a narrow phone or a large text.
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final wide = constraints.maxWidth / scale >= 300;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (figure case final big?) ...[
                            // Half the row at most: a long figure
                            // («550,000») shrinks rather than push the
                            // words off the card; the home's days fit.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.5,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  big,
                                  key:
                                      figureKey ??
                                      const ValueKey('plan-hero-figure'),
                                  style: JourneyType.of(
                                    JourneyType.homeCount,
                                    weight: JourneyType.bold,
                                    color: AarastV3Color.onPrimary,
                                    height: 0.95,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AarastV3Space.x2),
                          ],
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: AarastV3Space.x1,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: JourneyType.of(
                                      JourneyType.title,
                                      weight: JourneyType.bold,
                                      color: AarastV3Color.onPrimary,
                                    ),
                                  ),
                                  if (subtitle case final line?)
                                    Text(
                                      line,
                                      style: JourneyType.of(
                                        JourneyType.bodySmall,
                                        color: AarastV3Color.onPrimary
                                            .withValues(alpha: 0.78),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (wide && tag != null) ...[
                            const SizedBox(width: AarastV3Space.x2),
                            // A long tag («أرسل الدعوة لـ124 ضيف») wraps in
                            // its share of the row, never off the card.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.42,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AarastV3Space.x1,
                                ),
                                child: tag,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!wide && tag != null) ...[
                        const SizedBox(height: AarastV3Space.x3),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: tag,
                        ),
                      ],
                      if (footer case final under?) ...[
                        const SizedBox(height: AarastV3Space.x3),
                        under,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final tap = onTap;
    return Semantics(
      container: true,
      button: tap != null,
      label: semanticLabel,
      onTap: tap,
      child: tap == null
          ? card
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: card,
            ),
    );
  }
}

/// The home's saffron tag, for a hero's row: a word, and a small icon when
/// it opens something.
class JourneyHeroTag extends StatelessWidget {
  const JourneyHeroTag({
    required this.label,
    this.icon,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: AarastV3Density.tagInsets,
      decoration: BoxDecoration(
        color: AarastV3Color.saffron,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
              ),
            ),
          ),
          if (icon case final glyph?) ...[
            const SizedBox(width: AarastV3Space.x1),
            Icon(glyph, size: 14),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return pill;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(AarastV3Space.x1),
          child: pill,
        ),
      ),
    );
  }
}

/// A hero's footer bar in the home's moments' look: 6 high, the share done
/// in white over a faint white track.
class JourneyHeroBar extends StatelessWidget {
  const JourneyHeroBar({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return JourneyBar(
      value: value,
      color: AarastV3Color.onPrimary,
      track: AarastV3Color.onPrimary.withValues(alpha: 0.22),
    );
  }
}
