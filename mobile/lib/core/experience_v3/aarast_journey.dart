import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:lucide_icons/lucide_icons.dart';

import '../widgets/aarast_loading_state.dart' show AarastInlineSpinner;
import '../widgets/aarast_pressable.dart';
import 'aarast_journey_entry.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// The wordmark's dot sits this share of the type size under the word.
const _wordmarkDotLift = 0.12;

/// The journey kit: the building blocks of every journey screen.
///
/// Screens are composed from these so the app looks like the approved design
/// and every section keeps its colour. Everything reads its colour from
/// [AarastV3Color], scales with the user's text size, and is reachable by
/// screen readers.
abstract final class JourneyType {
  static const family = AarastV3Type.bodyFamily;

  // The one type scale (D8, D118): nine roles, each a clear step from the
  // next, for the phones people hold (360-400 wide). It was twenty-two
  // sizes half a point apart, so nothing on a screen read as more important
  // than its neighbour. The text scale on top stops at 1.3
  // (DevicePreferences.textScalerFor). Screens take a role, never a number.

  /// The home countdown's days.
  static const homeCount = 52.0;

  /// The one big number of a screen or a card: the days to the wedding, the
  /// money's gap.
  static const count = 32.0;

  /// A tab's title, an onboarding question, a typed amount.
  static const hero = 24.0;

  /// A pushed screen's or a sheet's title, a heading inside a screen, a
  /// figure inside a card.
  static const pageTitle = 19.0;

  /// A card's or a section's title, a field's value, a main action's label.
  static const lead = 16.0;

  /// Running text and list titles.
  static const body = 14.5;

  /// Secondary lines, hints, chips, a field's label, section tabs.
  static const small = 12.5;

  /// The smallest text: tags, the Hijri date under a day.
  static const caption = 11.0;

  /// The count inside a 16-point badge dot; it does not grow with text size.
  static const badge = 9.0;

  static TextStyle of(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AarastV3Color.ink,
    double height = AarastV3Line.normal,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  static const bold = FontWeight.w700;
}

/// The five tabs. A section keeps its colour on every screen; the home and
/// the money take the plan's own colour (teal for the groom, rose for the
/// bride), the other three are the same for both.
enum JourneySection {
  home('الرئيسية', 'الرئيسية', LucideIcons.home),
  money('المال', 'المال', LucideIcons.wallet),
  tasks('المهام', 'المهام', LucideIcons.listChecks),
  guests('الضيوف', 'الضيفات', LucideIcons.users),
  providers('المزودين', 'المزودين', LucideIcons.store);

  const JourneySection(this._groomLabel, this._brideLabel, this.icon);

  final String _groomLabel;
  final String _brideLabel;
  final IconData icon;

  /// The tab's name in the open plan's words (B5): a bride's guests are
  /// «الضيفات» whoever reads her plan.
  String labelOf(BuildContext context) =>
      context.planWord(_groomLabel, _brideLabel);

  /// One colour for the whole plan: every tab wears the plan's own colour.
  Color colorOf(BuildContext context) => context.accent.primary;

  Color softOf(BuildContext context) => context.accent.primarySoft;
}

/// A white rounded surface. [borderColor] draws a 2px outline (selection or
/// warning), never a shadow.
class JourneyBox extends StatelessWidget {
  const JourneyBox({
    required this.child,
    this.color = AarastV3Color.paper,
    this.padding = const EdgeInsets.all(AarastV3Space.x4),
    this.radius = AarastV3Radius.card,
    this.borderColor,
    this.borderWidth = AarastV3Space.half,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  /// The edge's width when [borderColor] is set; a hairline
  /// ([AarastV3Space.hair]) for a card that sits on the canvas.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A square icon on a soft fill.
class JourneyIconTile extends StatelessWidget {
  const JourneyIconTile({
    required this.icon,
    required this.color,
    required this.soft,
    this.size = AarastV3Size.mark,
    this.radius = AarastV3Radius.control,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, size: size * 0.45, color: color),
      ),
    );
  }
}

/// A filled button. [onPressed] null disables it; [loading] shows a spinner.
class JourneyButton extends StatelessWidget {
  const JourneyButton({
    required this.label,
    required this.onPressed,
    this.background,
    this.foreground = AarastV3Color.onPrimary,
    this.icon,
    this.expand = false,
    this.large = false,
    this.loading = false,
    super.key,
  }) : outline = false;

  /// A way in that is not the main one (the door's «تسجيل الدخول»): white,
  /// a hairline, the words in the plan's deep colour.
  const JourneyButton.outline({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.large = false,
    this.loading = false,
    super.key,
  }) : background = AarastV3Color.paper,
       foreground = AarastV3Color.ink,
       outline = true;

  /// The quiet variant used next to a main action.
  const JourneyButton.quiet({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.large = false,
    this.loading = false,
    super.key,
  }) : background = AarastV3Color.canvas,
       foreground = AarastV3Color.textMuted,
       outline = false;

  final String label;
  final VoidCallback? onPressed;

  /// The fill; the plan's colour when null.
  final Color? background;
  final Color foreground;
  final IconData? icon;
  final bool expand;
  final bool large;
  final bool loading;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    // Not ready yet reads as a pale fill with grey words, never as an
    // outline (an outline is a live second way).
    final bg = enabled
        ? background ?? context.accent.primary
        : AarastV3Color.line;
    final fg = !enabled
        ? AarastV3Color.textMuted
        : outline
        ? context.accent.primaryDark
        : foreground;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          AarastInlineSpinner(color: fg),
          const SizedBox(width: AarastV3Space.x2),
        ] else if (icon != null) ...[
          Icon(icon, size: AarastV3Icon.md, color: fg),
          const SizedBox(width: AarastV3Space.x2),
        ],
        // A button's words are one line: they shrink a little in a narrow
        // button rather than break («حفظ» over «الضيف»).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: JourneyType.of(
                large ? JourneyType.lead : JourneyType.body,
                weight: JourneyType.bold,
                color: fg,
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        child: Container(
          width: expand ? double.infinity : null,
          // Every button is one height (D118); the main one only carries the
          // larger label (D74).
          constraints: const BoxConstraints(minHeight: AarastV3Size.action),
          padding: EdgeInsets.symmetric(
            horizontal: AarastV3Space.x4,
            vertical: large ? AarastV3Space.x3 : AarastV3Space.x2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: outline && enabled
                ? Border.all(color: AarastV3Color.lineStrong)
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A plain text action, for "skip" lines and secondary links.
class JourneyTextAction extends StatelessWidget {
  const JourneyTextAction({
    required this.label,
    required this.onPressed,
    this.color = AarastV3Color.textMuted,
    this.icon,
    this.sub,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  /// A smaller line under the label (what the way out keeps, D75).
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? this.color : AarastV3Color.textFaint;
    final sub = this.sub;
    return Semantics(
      button: true,
      enabled: enabled,
      label: [label, ?sub].join('، '),
      onTap: onPressed,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: ConstrainedBox(
          // A 48 target (DESIGN_SYSTEM); the words themselves do not grow.
          constraints: const BoxConstraints(minHeight: AarastV3Size.touch),
          child: Padding(
            padding: const EdgeInsets.all(AarastV3Space.x2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AarastV3Icon.sm, color: color),
                  const SizedBox(width: AarastV3Space.x2),
                ],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                          color: color,
                        ),
                      ),
                      if (sub != null)
                        Text(
                          sub,
                          textAlign: TextAlign.center,
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable chip. [selected] fills it with [selectedColor].
class JourneyChip extends StatelessWidget {
  const JourneyChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.selectedColor,
    this.fontSize = JourneyType.small,
    this.large = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The selected fill; the plan's colour when null.
  final Color? selectedColor;
  final double fontSize;

  /// A chip that is the answer to a question (the city): a full 48 target
  /// and a round pill.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AarastV3Color.onPrimary : AarastV3Color.ink;
    final radius = large ? AarastV3Radius.pill : AarastV3Radius.surface;
    final drawn = _drawn(context, fg, radius);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(radius),
        // RA-MO-28 (D74): a chip that can be touched is touched in a 48
        // band; its drawing stays about 36, as a round button stays 44.
        child: onTap == null || large
            ? drawn
            : ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AarastV3Size.touch,
                ),
                child: Align(widthFactor: 1, child: drawn),
              ),
      ),
    );
  }

  Widget _drawn(BuildContext context, Color fg, double radius) {
    final fill = selected
        ? selectedColor ?? context.accent.primary
        : AarastV3Color.paper;
    return Container(
      constraints: BoxConstraints(
        minHeight: large ? AarastV3Size.touch : AarastV3Size.chip,
      ),
      padding: large
          ? const EdgeInsets.symmetric(horizontal: AarastV3Space.x4)
          : AarastV3Density.chipInsets,
      // A chosen chip keeps a line in its own fill, so chosen and not are
      // one height at every text size (D118).
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: selected ? fill : AarastV3Color.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AarastV3Icon.sm, color: fg),
            const SizedBox(width: AarastV3Space.x1),
          ],
          Flexible(
            child: Text(
              label,
              style: JourneyType.of(
                fontSize,
                weight: JourneyType.bold,
                color: fg,
                height: AarastV3Line.tight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small status word on a soft fill («محجوز»، «مبدئي»، «ينتظر ردك»).
class JourneyTag extends StatelessWidget {
  const JourneyTag({
    required this.label,
    required this.color,
    required this.soft,
    super.key,
  });

  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x2,
        vertical: AarastV3Space.x1,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Text(
        label,
        style: JourneyType.of(
          JourneyType.caption,
          weight: JourneyType.bold,
          color: color,
        ),
      ),
    );
  }
}

/// A progress bar. [value] is 0 to 1.
class JourneyBar extends StatelessWidget {
  const JourneyBar({
    required this.value,
    required this.color,
    this.track = AarastV3Color.line,
    this.height = 6,
    super.key,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          // An empty ColoredBox has no height of its own; stretch gives the
          // bar its height.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (v > 0)
              Expanded(
                flex: (v * 1000).round(),
                child: ColoredBox(color: color),
              ),
            if (v < 1)
              Expanded(
                flex: ((1 - v) * 1000).round(),
                child: ColoredBox(color: track),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segmented steps: the first [done] filled, the current one in [current].
class JourneySegments extends StatelessWidget {
  const JourneySegments({
    required this.total,
    required this.done,
    this.filled,
    this.current,
    this.empty = AarastV3Color.line,
    this.height = 6,
    super.key,
  });

  final int total;
  final int done;

  /// The done and current steps; the plan's colour when null.
  final Color? filled;
  final Color? current;
  final Color empty;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: height,
                margin: EdgeInsetsDirectional.only(
                  end: i == total - AarastV3Space.hair ? 0 : AarastV3Space.x1,
                ),
                decoration: BoxDecoration(
                  color: i < done
                      ? filled ?? context.accent.primary
                      : i == done
                      ? current ?? context.accent.primary
                      : empty,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small segmented choice of one level («لا / يشوف / يعدّل»): the words sit
/// in a grey track and the chosen one on a white pill in [color] (g06).
/// Without [onChanged] it rests.
class JourneyLevelSwitch extends StatelessWidget {
  const JourneyLevelSwitch({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.color,
    super.key,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  /// What the switch sets («المهام»); each word is read with it.
  final String semanticLabel;

  /// The chosen word's colour; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final color = this.color ?? context.accent.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(AarastV3Space.x1),
        decoration: BoxDecoration(
          color: AarastV3Color.line,
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              Semantics(
                button: true,
                selected: i == selected,
                enabled: enabled,
                label: '$semanticLabel: ${options[i]}',
                onTap: enabled ? () => onChanged!(i) : null,
                excludeSemantics: true,
                child: AarastPressable(
                  onTap: enabled ? () => onChanged!(i) : null,
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                  child: Container(
                    // Critique ط6: 48, as every target in the kit (D74); at
                    // 32 a slip here gave a participant the money.
                    // A short word («لا») is still a full 48 wide.
                    constraints: const BoxConstraints(
                      minHeight: AarastV3Size.touch,
                      minWidth: AarastV3Size.touch,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AarastV3Space.x2,
                      vertical: AarastV3Space.x1,
                    ),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AarastV3Color.paper
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                    ),
                    child: Text(
                      options[i],
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: i == selected ? color : AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A round 44px button on the page (back, search, actions), touched in a
/// 48 square around it (DESIGN_SYSTEM: touch targets ≥ 48).
class JourneyRoundButton extends StatelessWidget {
  const JourneyRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AarastV3Size.mark,
    this.onArt = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Over a picture (the wedding sky): a see-through white disc, a white icon.
  final bool onArt;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        onTap: onPressed,
        excludeSemantics: true,
        child: AarastPressable(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size),
          child: SizedBox.square(
            dimension: size < AarastV3Size.touch ? AarastV3Size.touch : size,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: onArt
                      ? AarastV3Color.paper.withValues(alpha: 0.2)
                      : AarastV3Color.paper,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AarastV3Icon.md,
                  color: onArt ? AarastV3Color.paper : AarastV3Color.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header of a main tab: big title, status line, round actions.
class JourneyTabHeader extends StatelessWidget {
  const JourneyTabHeader({
    required this.title,
    required this.status,
    this.actions = const [],
    this.onStatusTap,
    this.statusTapLabel,
    super.key,
  });

  final String title;
  final String status;
  final List<Widget> actions;

  /// Pressing the status line opens what it counts, as «محجوز 3» opens the
  /// bookings (w34); [statusTapLabel] tells screen readers so.
  final VoidCallback? onStatusTap;
  final String? statusTapLabel;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: JourneyType.of(JourneyType.hero, weight: JourneyType.bold),
      ),
    );
    final statusLine = onStatusTap == null
        ? Text(
            status,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          )
        // A pressable status line used to be drawn exactly like a plain
        // one: same size, same muted colour, no mark. The bookings (w34)
        // hung off it and so had no visible door at all. It now reads as
        // the app's other links do — the plan's colour and a chevron.
        : AarastPressable(
            onTap: onStatusTap,
            semanticLabel: statusTapLabel,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    status,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: context.accent.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AarastV3Space.half),
                Icon(
                  LucideIcons.chevronLeft,
                  size: AarastV3Icon.sm,
                  color: context.accent.primary,
                ),
              ],
            ),
          );
    // Rashad 2026-11-18: the status on its own line under the title was
    // height lost on every tab. It sits at the title's line end whenever
    // the title, the status and the buttons fit on one line at this width
    // and text size; when they do not, it goes under the title as before,
    // so nothing is squeezed or cut.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        double widthOf(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.rtl,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          // Review 2026-11-18: a painter holds native text resources.
          painter.dispose();
          return width;
        }

        final titleWidth = widthOf(
          title,
          JourneyType.of(JourneyType.hero, weight: JourneyType.bold),
        );
        final statusWidth =
            widthOf(
              status,
              onStatusTap == null
                  ? JourneyType.of(JourneyType.body)
                  : JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ) +
            (onStatusTap == null ? 0 : AarastV3Space.half + 16);
        final actionsWidth =
            actions.length * (AarastV3Size.touch + AarastV3Space.x2);
        final room = constraints.maxWidth - AarastV3Space.x2;
        if (titleWidth + AarastV3Space.x4 + statusWidth + actionsWidth <=
            room) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x1,
              AarastV3Space.x1,
              AarastV3Space.x1,
              AarastV3Space.x2,
            ),
            child: Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: AarastV3Space.x4),
                statusLine,
                for (final action in actions) ...[
                  const SizedBox(width: AarastV3Space.x2),
                  action,
                ],
              ],
            ),
          );
        }
        return _stacked(heading, statusLine);
      },
    );
  }

  Widget _stacked(Widget heading, Widget statusLine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x1,
        AarastV3Space.x1,
        AarastV3Space.x1,
        AarastV3Space.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AarastV3Space.half),
                statusLine,
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AarastV3Space.x2),
            action,
          ],
        ],
      ),
    );
  }
}

/// Header of a pushed screen: back arrow, title, optional subtitle.
class JourneySubHeader extends StatelessWidget {
  const JourneySubHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.onTitleTap,
    this.titleTapLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Pressing the title opens what belongs to it, as a conversation's name
  /// opens its options (w32); [titleTapLabel] tells screen readers so.
  final VoidCallback? onTitleTap;
  final String? titleTapLabel;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Semantics(
            header: true,
            child: Text(
              title,
              style: JourneyType.of(
                JourneyType.pageTitle,
                weight: JourneyType.bold,
              ),
            ),
          ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.half,
        AarastV3Space.x1,
        AarastV3Space.half,
        AarastV3Space.x3,
      ),
      child: Row(
        children: [
          JourneyRoundButton(
            icon: LucideIcons.arrowRight,
            tooltip: 'رجوع',
            size: AarastV3Size.mark,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: onTitleTap == null
                ? heading
                : AarastPressable(
                    onTap: onTitleTap,
                    semanticLabel: titleTapLabel,
                    borderRadius: BorderRadius.circular(AarastV3Radius.control),
                    child: SizedBox(width: double.infinity, child: heading),
                  ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A section title with an optional action on the other end.
class JourneySectionTitle extends StatelessWidget {
  const JourneySectionTitle(
    this.title, {
    this.action,
    this.onAction,
    this.actionColor,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// The link's colour; the plan's colour when null.
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x1,
        AarastV3Space.x5,
        AarastV3Space.x1,
        AarastV3Space.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                ),
              ),
            ),
          ),
          // The link sits at the far end, as drawn. A Flexible here shared
          // the row with the title and left the link mid-row; a width cap
          // still lets large text wrap it instead of pushing it off.
          if (action != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .45,
              ),
              child: _SectionLink(
                label: action!,
                onTap: onAction,
                color: actionColor ?? context.accent.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// A section title's link: plain 14 bold words, as drawn. The tap area
/// reaches 12 past the words and as tall as the title line, so the row keeps
/// its height.
class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      // Secondary beside its title: the small size, so the row keeps the
      // title's height (D118).
      style: JourneyType.of(
        JourneyType.small,
        weight: JourneyType.bold,
        color: color,
      ),
    );
    if (onTap == null) return text;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(AarastV3Radius.control),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AarastV3Space.x3,
          AarastV3Space.half,
          0,
          AarastV3Space.half,
        ),
        child: text,
      ),
    );
  }
}

/// A row in a white list: icon tile, title, one-line subtitle, trailing.
/// The most of a list row its end (an amount, a tag) takes.
const _trailingShare = 0.4;

class JourneyListRow extends StatelessWidget {
  const JourneyListRow({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconSize = AarastV3Size.mark,
    this.subtitleMaxLines = 1,
    super.key,
  });

  /// A line that names several things (the plan's items) may take more.
  final int subtitleMaxLines;

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: AarastV3Density.chipInsets,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            JourneyIconTile(
              icon: icon,
              color: color,
              soft: soft,
              size: iconSize,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: AarastV3Size.titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AarastV3Space.x2),
              // An amount or a tag takes at most two fifths of the row itself
              // (it took 45% of the screen, and squeezed the title onto two
              // lines), and shrinks in it rather than wrap.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _trailingShare,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: '$title، $subtitle',
      child: row,
    );
  }
}

/// A white card holding rows, with hairline dividers between them.
class JourneyList extends StatelessWidget {
  const JourneyList({required this.children, this.dividers = true, super.key});

  final List<Widget> children;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 && dividers)
                const Divider(
                  height: AarastV3Space.hair,
                  indent: 70,
                  endIndent: 14,
                  color: AarastV3Color.line,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A large choice card: icon or picture, title, subtitle, selected outline.
///
/// The radio ring belongs to a card that is one answer among answers, where
/// something later confirms the pick. A card that acts the moment it is
/// tapped is not that, and a ring on it promises a choice to confirm that
/// never comes: the guests' empty list drew three rings that could never
/// fill. Such a card passes [choosable] false and gets a chevron, the
/// app's mark for «this opens something».
class JourneyChoiceCard extends StatelessWidget {
  const JourneyChoiceCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
    this.selected = false,
    this.choosable = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;
  final bool selected;

  /// Whether this card is one answer among answers. False for a card that
  /// acts at once.
  final bool choosable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choosable ? selected : null,
      label: '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: Container(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          decoration: BoxDecoration(
            color: selected ? context.accent.primarySoft : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
            border: Border.all(
              color: selected ? context.accent.primary : AarastV3Color.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.lead,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.half),
                    Text(
                      subtitle,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              if (choosable)
                _SelectionMark(selected: selected)
              else
                const Icon(
                  LucideIcons.chevronLeft,
                  size: AarastV3Icon.md,
                  color: AarastV3Color.textFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One answer in a short list of answers (prototype `gOption`): a radio
/// ring, the answer and an optional explanation under it. The chosen one is
/// outlined in [color] and its ring fills.
class JourneyOption extends StatelessWidget {
  const JourneyOption({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.color,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool selected;

  /// The chosen outline; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.accent.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        child: Container(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: Border.all(
              color: selected ? color : AarastV3Color.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AarastV3Size.check,
                height: AarastV3Size.check,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : AarastV3Color.line,
                    width: selected ? 7 : 2,
                  ),
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One way to start in [JourneyStartWays].
class JourneyStartWay {
  const JourneyStartWay({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? key;
}

/// A tab's first visit (x21, x22): a big icon, what to start with and why,
/// and the ways to start. The first way is the one we suggest, so it carries
/// the tab's colour as a border.
class JourneyStartWays extends StatelessWidget {
  const JourneyStartWays({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.message,
    required this.ways,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String message;
  final List<JourneyStartWay> ways;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AarastV3Space.x1),
        Center(
          child: JourneyIconTile(
            icon: icon,
            color: color,
            soft: soft,
            size: AarastV3Size.markHero,
            radius: 28,
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.pageTitle,
              weight: JourneyType.bold,
            ),
          ),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Text(
          message,
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
            height: AarastV3Line.reading,
          ),
        ),
        const SizedBox(height: AarastV3Space.x5),
        for (var i = 0; i < ways.length; i++) ...[
          if (i > 0) const SizedBox(height: AarastV3Space.x2),
          AarastPressable(
            key: ways[i].key,
            onTap: ways[i].onTap,
            semanticLabel: '${ways[i].title}، ${ways[i].subtitle}',
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
            child: Container(
              padding: const EdgeInsets.all(AarastV3Space.x3),
              decoration: BoxDecoration(
                color: AarastV3Color.paper,
                borderRadius: BorderRadius.circular(AarastV3Radius.card),
                border: i == 0
                    ? Border.all(color: color, width: AarastV3Size.lineStrong)
                    : null,
              ),
              child: Row(
                children: [
                  JourneyIconTile(
                    icon: ways[i].icon,
                    color: color,
                    soft: soft,
                    size: AarastV3Size.mark,
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ways[i].title,
                          style: JourneyType.of(
                            JourneyType.lead,
                            weight: JourneyType.bold,
                          ),
                        ),
                        Text(
                          ways[i].subtitle,
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  const Icon(
                    LucideIcons.chevronLeft,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.textFaint,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AarastV3Size.check,
      height: AarastV3Size.check,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.accent.primary : AarastV3Color.paper,
        border: selected
            ? null
            : Border.all(
                color: AarastV3Color.lineStrong,
                width: AarastV3Size.lineStrong,
              ),
      ),
      child: selected
          ? const Icon(
              LucideIcons.check,
              size: AarastV3Icon.sm,
              color: AarastV3Color.onPrimary,
            )
          : null,
    );
  }
}

/// The wordmark: اعّرست with its saffron dot.
class JourneyWordmark extends StatelessWidget {
  const JourneyWordmark({
    this.size = AarastV3Icon.feature,
    this.color,
    super.key,
  });

  final double size;

  /// The word's colour; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.accent.primary;
    return Semantics(
      label: 'اعّرست',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اعّرست',
            textScaler: TextScaler.noScaling,
            style: JourneyType.of(
              size,
              weight: JourneyType.bold,
              color: color,
              height: AarastV3Line.tight,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * _wordmarkDotLift),
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: const BoxDecoration(
                color: JourneyPalette.saffron,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colours that only decorate (never text on paper): the saffron of the
/// wordmark dot and the lights.
abstract final class JourneyPalette {
  static const saffron = AarastV3Color.saffron;
}

/// A round letter avatar.
class JourneyAvatar extends StatelessWidget {
  const JourneyAvatar({
    required this.letter,
    required this.color,
    this.size = AarastV3Size.markSmall,
    super.key,
  });

  final String letter;
  final Color color;
  final double size;

  /// The colours people in one list take in turn (g01, x07, x20); the
  /// second is the plan's own colour.
  static Color paletteAt(BuildContext context, int index) => [
    AarastV3Color.brandAccentStrong,
    context.accent.primary,
    AarastV3Color.lilac,
    AarastV3Color.cobalt,
  ][index % 4];

  /// RA-MO-27: the letter in white or in ink, whichever reads more on the
  /// fill (saffron takes ink: white on it is about 2:1).
  static Color onFill(Color fill) {
    final fillLuminance = fill.computeLuminance();
    double contrast(Color other) {
      final otherLuminance = other.computeLuminance();
      final light = otherLuminance > fillLuminance
          ? otherLuminance
          : fillLuminance;
      final dark = otherLuminance > fillLuminance
          ? fillLuminance
          : otherLuminance;
      return (light + 0.05) / (dark + 0.05);
    }

    return contrast(AarastV3Color.onPrimary) >= contrast(AarastV3Color.ink)
        ? AarastV3Color.onPrimary
        : AarastV3Color.ink;
  }

  @override
  Widget build(BuildContext context) {
    final ink = onFill(color);
    final shown = letter.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        // RA-MO-27: no name, no made-up letter; a person instead.
        child: shown.isEmpty
            ? Icon(LucideIcons.user, size: size * 0.5, color: ink)
            : Text(
                shown,
                textScaler: TextScaler.noScaling,
                style: JourneyType.of(
                  size * 0.45,
                  weight: JourneyType.bold,
                  color: ink,
                ),
              ),
      ),
    );
  }
}

/// The page frame of a journey screen: canvas, scrolling body, an optional
/// fixed bottom area (main action) that stays above the keyboard.
class JourneyPage extends StatelessWidget {
  const JourneyPage({
    required this.children,
    this.bottom,
    this.padding = const EdgeInsets.symmetric(horizontal: AarastV3Space.x4),
    this.background = AarastV3Color.canvas,
    super.key,
  });

  final List<Widget> children;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: padding.add(
                  const EdgeInsets.only(
                    top: AarastV3Space.x2,
                    bottom: AarastV3Space.x5,
                  ),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: children,
              ),
            ),
            if (bottom != null)
              Padding(padding: AarastV3Density.actionInsets, child: bottom),
          ],
        ),
      ),
    );
  }
}

/// One onboarding question per screen: progress, question, help, body, and
/// the main button with an optional skip line under it.
class JourneyQuestionPage extends StatelessWidget {
  const JourneyQuestionPage({
    required this.step,
    required this.total,
    required this.question,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    this.help,
    this.skipLabel,
    this.onSkip,
    this.loading = false,
    super.key,
  });

  /// Zero-based index of this question.
  final int step;
  final int total;
  final String question;
  final String? help;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onBack;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return JourneyPage(
      bottom: JourneyEntryActions(
        primary: JourneyButton(
          label: primaryLabel,
          onPressed: onPrimary,
          expand: true,
          large: true,
          loading: loading,
        ),
        secondary: skipLabel == null
            ? null
            : JourneyTextAction(label: skipLabel!, onPressed: onSkip),
      ),
      children: [
        JourneyStepBar(onBack: onBack, step: step + 1, total: total),
        JourneyEntryQuestion(question: question, help: help),
        const SizedBox(height: AarastV3Space.x5),
        ...children,
      ],
    );
  }
}

/// A frame of art that carries words (D118): the art fills it, the words sit
/// at its foot, and it is at least [ratio] of its width tall. When the words
/// need more (a large text size, a narrow phone) the frame grows; it never
/// cuts them and never stands on a fixed height.
class JourneyArtFrame extends StatelessWidget {
  const JourneyArtFrame({
    required this.ratio,
    required this.art,
    required this.child,
    this.padding = const EdgeInsets.all(AarastV3Space.x5),
    super.key,
  });

  /// Width over height at the least ([AarastV3Media]).
  final double ratio;
  final Widget art;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: width / ratio),
          child: Stack(
            alignment: AlignmentDirectional.bottomStart,
            children: [
              Positioned.fill(child: art),
              SizedBox(
                width: width,
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The one field box (D74, D118). Every field, typed, picked or a phone, is
/// this box: white, the field corner, a hairline that turns the plan's colour
/// at 2 on focus and coral on an error or a reviewer's note, and one height
/// ([AarastV3Size.field], a typed amount [AarastV3Size.fieldAmount]). The
/// whole box takes the tap (RA-MO-27).
class JourneyFieldBox extends StatelessWidget {
  const JourneyFieldBox({
    required this.child,
    this.trailing,
    this.focused = false,
    this.error = false,
    this.large = false,
    this.onTap,
    super.key,
  });

  final Widget child;

  /// A tool at the far end (the password eye, «لصق»). It stands outside the
  /// box's inner padding, so a full 48 target fits the field's height.
  final Widget? trailing;
  final bool focused;

  /// An error or a note: the coral edge.
  final bool error;

  /// A typed amount.
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AarastV3Color.danger
        : focused
        ? context.accent.primary
        : AarastV3Color.line;
    final trailing = this.trailing;
    final box = Container(
      constraints: BoxConstraints(
        minHeight: large ? AarastV3Size.fieldAmount : AarastV3Size.field,
      ),
      alignment: AlignmentDirectional.centerStart,
      padding: trailing == null
          ? AarastV3Field.padding
          : const EdgeInsetsDirectional.only(end: AarastV3Space.x1),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Field.radius),
        border: Border.all(color: color, width: error || focused ? 2 : 1),
      ),
      child: trailing == null
          ? child
          : Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AarastV3Space.x4,
                      end: AarastV3Space.x2,
                      top: AarastV3Space.x2,
                      bottom: AarastV3Space.x2,
                    ),
                    child: child,
                  ),
                ),
                trailing,
              ],
            ),
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: box,
    );
  }
}

/// The small name over a field's value.
class JourneyFieldLabel extends StatelessWidget {
  const JourneyFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
      height: AarastV3Field.labelHeight,
    ),
  );
}

/// A field's error, under its box.
class JourneyFieldError extends StatelessWidget {
  const JourneyFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AarastV3Space.x2,
      AarastV3Space.x1,
      AarastV3Space.x2,
      0,
    ),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: AarastV3Icon.sm,
            color: AarastV3Color.danger,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              message,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A labelled input in the journey's look: small label, large value,
/// 2px teal outline while focused.
class JourneyTextField extends StatefulWidget {
  const JourneyTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.large = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.helper,
    this.helperColor,
    this.autofillHints,
    this.minLines,
    this.maxLines = 1,
    this.trailing,
    this.enabled = true,
    this.validator,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Inside a [Form], checked when the form validates; its message shows as
  /// the field's error.
  final FormFieldValidator<String>? validator;

  /// False while a form saves or a contact is being picked.
  final bool enabled;

  /// An action at the field's far end (the invite link's «لصق»).
  final Widget? trailing;
  final String? hint;
  final IconData? icon;
  final String? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool large;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final TextDirection? textDirection;

  /// An amount typed left to right still sits on the reading side with
  /// [TextAlign.right].
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;

  /// The helper line's colour; the plan's colour when null.
  final Color? helperColor;
  final Iterable<String>? autofillHints;

  /// A note or a pasted list grows from [minLines] up to [maxLines].
  final int? minLines;
  final int? maxLines;

  @override
  State<JourneyTextField> createState() => _JourneyTextFieldState();
}

class _JourneyTextFieldState extends State<JourneyTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validator = widget.validator;
    if (validator == null) return _field(widget.errorText, widget.onChanged);
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) => validator(widget.controller.text),
      builder: (state) => _field(state.errorText ?? widget.errorText, (value) {
        state.didChange(value);
        widget.onChanged?.call(value);
      }),
    );
  }

  Widget _field(String? error, ValueChanged<String>? onChanged) {
    final valueSize = widget.large ? JourneyType.hero : JourneyType.lead;
    // A phone number reads left to right inside Arabic, unless the screen
    // says otherwise.
    final textDirection =
        widget.textDirection ??
        (widget.keyboardType == TextInputType.phone
            ? TextDirection.ltr
            : Directionality.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyFieldBox(
          focused: _focus.hasFocus,
          error: error != null,
          large: widget.large,
          onTap: _focus.requestFocus,
          trailing: widget.trailing,
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: AarastV3Icon.md,
                  color: AarastV3Color.textMuted,
                ),
                const SizedBox(width: AarastV3Field.iconGap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JourneyFieldLabel(widget.label),
                    TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      obscureText: widget.obscureText,
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxLength,
                      textDirection: textDirection,
                      textAlign: widget.textAlign,
                      autofillHints: widget.autofillHints,
                      inputFormatters: widget.inputFormatters,
                      onChanged: onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: JourneyType.of(
                        valueSize,
                        weight: JourneyType.bold,
                        height: AarastV3Field.valueHeight,
                      ),
                      cursorColor: context.accent.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: widget.hint,
                        hintTextDirection: textDirection,
                        // RA-MO-27: an example in the regular weight, so it
                        // never reads as a value already typed.
                        hintStyle: JourneyType.of(
                          valueSize,
                          color: AarastV3Color.textFaint,
                          height: AarastV3Field.valueHeight,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (widget.helper != null && error == null)
                      Text(
                        widget.helper!,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: widget.helperColor ?? context.accent.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.suffix != null)
                Text(
                  widget.suffix!,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (error != null) JourneyFieldError(error),
      ],
    );
  }
}

/// A tappable field that opens a picker (date, place).
///
/// With a [note] it is the provider prototype's `pField(note:)`: a 2 coral
/// border and the reviewer's note under the value (p09).
class JourneyPickerField extends StatelessWidget {
  const JourneyPickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.placeholder = 'اختر',
    this.helper,
    this.note,
    this.iconAtEnd = false,
    super.key,
  });

  final String label;
  final String? value;

  /// The icon after the words (a day picker), not before them.
  final bool iconAtEnd;

  /// Null shows a value that is read here and changed elsewhere (b13's
  /// Hijri day, the wedding's own day).
  final VoidCallback? onTap;
  final IconData? icon;
  final String placeholder;
  final String? helper;

  /// A note asking for a change to this field, drawn in coral under it.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    final note = this.note;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: ['$label، ${has ? value : placeholder}', ?note].join('، '),
      borderRadius: BorderRadius.circular(AarastV3Field.radius),
      child: JourneyFieldBox(
        error: note != null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null && !iconAtEnd) ...[
                  Icon(
                    icon,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.textMuted,
                  ),
                  const SizedBox(width: AarastV3Field.iconGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JourneyFieldLabel(label),
                      Text(
                        has ? value! : placeholder,
                        style: JourneyType.of(
                          JourneyType.lead,
                          weight: JourneyType.bold,
                          height: AarastV3Field.valueHeight,
                          color: has
                              ? AarastV3Color.ink
                              : AarastV3Color.textFaint,
                        ),
                      ),
                      if (helper != null)
                        Text(
                          helper!,
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (icon != null && iconAtEnd) ...[
                  const SizedBox(width: AarastV3Field.iconGap),
                  Icon(
                    icon,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.textMuted,
                  ),
                ],
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: AarastV3Space.x2),
              Container(
                padding: const EdgeInsets.all(AarastV3Space.x2),
                decoration: BoxDecoration(
                  color: AarastV3Color.dangerSoft,
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.messageSquare,
                      size: AarastV3Icon.sm,
                      color: AarastV3Color.danger,
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Text(
                        note,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.danger,
                          height: AarastV3Line.reading,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A one-line note on a soft fill, with a leading icon.
/// How a note sits: on the plan's soft fill (the app's usual note), on white
/// (information that changes a decision, D75), on saffron (a warning), or
/// bare (a small aside).
enum JourneyNoteTone { tinted, paper, warn, bare }

class JourneyNote extends StatelessWidget {
  const JourneyNote({
    required this.text,
    this.icon = LucideIcons.info,
    this.color,
    this.soft,
    this.tone = JourneyNoteTone.tinted,
    super.key,
  });

  final String text;
  final IconData icon;

  /// The words and fill (tinted), or the icon (the other tones); the plan's
  /// colours when null.
  final Color? color;
  final Color? soft;
  final JourneyNoteTone tone;

  @override
  Widget build(BuildContext context) {
    if (tone != JourneyNoteTone.tinted) return _toned(context);
    final color = this.color ?? context.accent.primary;
    final soft = this.soft ?? context.accent.primarySoft;
    return JourneyBox(
      color: soft,
      padding: const EdgeInsets.all(AarastV3Space.x3),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AarastV3Icon.md, color: color),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              text,
              // Critique ش4: a note in bold was louder than what it sits
              // beside; its fill and icon already set it apart.
              style: JourneyType.of(
                JourneyType.small,
                weight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toned(BuildContext context) {
    final warn = tone == JourneyNoteTone.warn;
    final iconColor = warn
        ? AarastV3Color.brandAccentStrong
        : color ?? context.accent.primary;
    if (tone == JourneyNoteTone.bare) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AarastV3Space.half),
              child: Icon(icon, size: AarastV3Icon.sm, color: iconColor),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Text(
                text,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                  height: AarastV3Line.reading,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x3,
      ),
      decoration: BoxDecoration(
        color: warn ? AarastV3Color.brandAccentSoft : AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AarastV3Space.half),
            child: Icon(icon, size: AarastV3Icon.md, color: iconColor),
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.body,
                color: warn
                    ? AarastV3Color.brandAccentStrong
                    : AarastV3Color.textMuted,
                height: AarastV3Line.reading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's on/off switch: a 44×26 track with a 20-point thumb that sits
/// on the right when on (as drawn, D25). A row that carries it should flip
/// it from anywhere on the row too, so the tap target is the row's full
/// height; without [onChanged] it rests.
class JourneyToggle extends StatelessWidget {
  const JourneyToggle({
    required this.value,
    required this.onChanged,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// The track when on; the plan's colour when null.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final color = this.color ?? context.accent.primary;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: AarastV3Size.toggleWidth,
            height: AarastV3Size.toggleHeight,
            padding: const EdgeInsets.all(AarastV3Space.x1),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? color : AarastV3Color.line,
              borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            ),
            child: const SizedBox.square(
              dimension: AarastV3Space.x5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AarastV3Color.paper,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
