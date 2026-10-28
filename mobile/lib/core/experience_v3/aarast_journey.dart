import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:lucide_icons/lucide_icons.dart';

import '../widgets/aarast_loading_state.dart' show AarastInlineSpinner;
import '../widgets/aarast_pressable.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// The journey kit: the building blocks of the redesigned groom journey
/// (`mobile/test/prototype/v3`), as production widgets.
///
/// Screens are composed from these so the app looks like the approved design
/// and every section keeps its colour. Everything reads its colour from
/// [AarastV3Color], scales with the user's text size, and is reachable by
/// screen readers.
abstract final class JourneyType {
  static const family = AarastV3Type.bodyFamily;

  // The one type scale, the approved design's sizes (D30, which restores
  // the headings D8 had shrunk). The text scale on top stops at 1.3
  // (DevicePreferences.textScalerFor). Screens take a size from here, never
  // a number.

  /// The one big number of a screen, such as the days to the wedding.
  static const count = 40.0;

  /// The home countdown's days (b01, b02: 64).
  static const homeCount = 64.0;

  /// The money summary's big gap («2.5 مليون»).
  static const headline = 34.0;

  /// An onboarding question (JourneyQuestionPage).
  static const question = 30.0;

  /// A main tab's title (JourneyTabHeader).
  static const hero = 28.0;

  /// A typed amount or name in a large field.
  static const amount = 28.0;

  /// A heading inside a screen: a start card, a sheet-like card's title.
  static const display = 24.0;

  /// A sheet's title (JourneySheetBody).
  static const sheetTitle = 22.0;

  /// A figure inside a card: a quote's price, a lock key.
  static const figure = 22.0;

  /// A pushed screen's title (JourneySubHeader) and a figure in a stat box
  /// (w19 «موزّع / احتياط»).
  static const pageTitle = 20.0;

  /// A person's name on their profile, a card's lead figure.
  static const prominent = 19.0;

  /// A card title.
  static const title = 18.0;

  /// A section title, a field's value and a main action's label.
  static const lead = 17.0;

  /// List titles that stand out and the help under a question.
  static const bodyLarge = 16.0;

  /// Running text and list titles.
  static const body = 15.0;

  /// Chips, a section's link, a sheet's subtitle and a form's labels.
  static const bodySmall = 14.0;

  /// Section tabs and a pushed screen's subtitle.
  static const detail = 13.5;

  /// Secondary lines and hints.
  static const small = 13.0;

  /// A field's label.
  static const label = 12.5;

  /// The smallest text: tags and the Hijri date under a day.
  static const caption = 12.0;

  /// An inactive tab's name in the bottom bar (b02: 11.5, regular, muted).
  static const tabLabel = 11.5;

  /// The count inside a 16-point badge dot; it does not grow with text size.
  static const badge = 9.0;

  static TextStyle of(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AarastV3Color.ink,
    double height = 1.35,
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

  Color colorOf(BuildContext context) => switch (this) {
    JourneySection.home || JourneySection.money => context.accent.primary,
    JourneySection.tasks => AarastV3Color.brandAccentStrong,
    JourneySection.guests => AarastV3Color.lilac,
    JourneySection.providers => AarastV3Color.cobalt,
  };

  Color softOf(BuildContext context) => switch (this) {
    JourneySection.home || JourneySection.money => context.accent.primarySoft,
    JourneySection.tasks => AarastV3Color.brandAccentSoft,
    JourneySection.guests => AarastV3Color.lilacSoft,
    JourneySection.providers => AarastV3Color.cobaltSoft,
  };
}

/// A white rounded surface. [borderColor] draws a 2px outline (selection or
/// warning), never a shadow.
class JourneyBox extends StatelessWidget {
  const JourneyBox({
    required this.child,
    this.color = AarastV3Color.paper,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
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
    this.size = 44,
    this.radius = 14,
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
  });

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
       foreground = AarastV3Color.textMuted;

  final String label;
  final VoidCallback? onPressed;

  /// The fill; the plan's colour when null.
  final Color? background;
  final Color foreground;
  final IconData? icon;
  final bool expand;
  final bool large;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = enabled
        ? background ?? context.accent.primary
        : AarastV3Color.lineStrong;
    final fg = enabled ? foreground : AarastV3Color.paper;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          AarastInlineSpinner(color: fg),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              large ? JourneyType.lead : JourneyType.body,
              weight: JourneyType.bold,
              color: fg,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: expand ? double.infinity : null,
          // The prototype's main action: 16 above and below a 17 label.
          constraints: BoxConstraints(minHeight: large ? 52 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: large ? 16 : 11,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
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
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: color,
                    ),
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
    this.fontSize = JourneyType.bodySmall,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The selected fill; the plan's colour when null.
  final Color? selectedColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AarastV3Color.onPrimary : AarastV3Color.ink;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor ?? context.accent.primary
                : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: AarastV3Color.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: JourneyType.of(
                    fontSize,
                    weight: JourneyType.bold,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(9),
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
                margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 5),
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
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AarastV3Color.line,
          borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 32),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AarastV3Color.paper
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
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

/// A round 44px button on the page (back, search, actions).
class JourneyRoundButton extends StatelessWidget {
  const JourneyRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

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
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AarastV3Color.paper,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AarastV3Color.ink),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: JourneyType.of(
                      JourneyType.hero,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                if (onStatusTap == null)
                  Text(
                    status,
                    style: JourneyType.of(
                      JourneyType.body,
                      color: AarastV3Color.textMuted,
                    ),
                  )
                else
                  AarastPressable(
                    onTap: onStatusTap,
                    semanticLabel: statusTapLabel,
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      status,
                      style: JourneyType.of(
                        JourneyType.body,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
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
              JourneyType.detail,
              color: AarastV3Color.textMuted,
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
      child: Row(
        children: [
          JourneyRoundButton(
            icon: LucideIcons.arrowRight,
            tooltip: 'رجوع',
            size: 42,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: onTitleTap == null
                ? heading
                : AarastPressable(
                    onTap: onTitleTap,
                    semanticLabel: titleTapLabel,
                    borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
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
      style: JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: color,
      ),
    );
    if (onTap == null) return text;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 0, 2),
        child: text,
      ),
    );
  }
}

/// A row in a white list: icon tile, title, one-line subtitle, trailing.
class JourneyListRow extends StatelessWidget {
  const JourneyListRow({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconSize = 42,
    super.key,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          JourneyIconTile(icon: icon, color: color, soft: soft, size: iconSize),
          const SizedBox(width: 12),
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
                Text(
                  subtitle,
                  maxLines: 1,
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
            const SizedBox(width: 8),
            // An amount or a tag gets at most 45% of the row, so large text
            // wraps it instead of pushing the row off the screen.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .45,
              ),
              child: trailing,
            ),
          ],
        ],
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 && dividers)
                const Divider(
                  height: 1,
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
class JourneyChoiceCard extends StatelessWidget {
  const JourneyChoiceCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? context.accent.primarySoft : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? context.accent.primary : AarastV3Color.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),
              _SelectionMark(selected: selected),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AarastV3Color.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : AarastV3Color.line,
                    width: selected ? 7 : 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
        const SizedBox(height: 4),
        Center(
          child: JourneyIconTile(
            icon: icon,
            color: color,
            soft: soft,
            size: 84,
            radius: 28,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < ways.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          AarastPressable(
            key: ways[i].key,
            onTap: ways[i].onTap,
            semanticLabel: '${ways[i].title}، ${ways[i].subtitle}',
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AarastV3Color.paper,
                borderRadius: BorderRadius.circular(20),
                border: i == 0 ? Border.all(color: color, width: 2) : null,
              ),
              child: Row(
                children: [
                  JourneyIconTile(
                    icon: ways[i].icon,
                    color: color,
                    soft: soft,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ways[i].title,
                          style: JourneyType.of(
                            JourneyType.bodyLarge,
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
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.chevronLeft,
                    size: 18,
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
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.accent.primary : AarastV3Color.paper,
        border: selected
            ? null
            : Border.all(color: AarastV3Color.lineStrong, width: 2),
      ),
      child: selected
          ? const Icon(
              LucideIcons.check,
              size: 16,
              color: AarastV3Color.onPrimary,
            )
          : null,
    );
  }
}

/// The wordmark: اعّرست with its saffron dot.
class JourneyWordmark extends StatelessWidget {
  const JourneyWordmark({this.size = 40, this.color, super.key});

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
              height: 1.1,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.12),
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
    this.size = 28,
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

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: JourneyType.of(
            size * 0.45,
            weight: JourneyType.bold,
            color: AarastV3Color.onPrimary,
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
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
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
                padding: padding.add(const EdgeInsets.only(top: 8, bottom: 20)),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: children,
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
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
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          JourneyButton(
            label: primaryLabel,
            onPressed: onPrimary,
            expand: true,
            large: true,
            loading: loading,
          ),
          if (skipLabel != null) ...[
            const SizedBox(height: 6),
            JourneyTextAction(label: skipLabel!, onPressed: onSkip),
          ],
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Row(
            children: [
              JourneyRoundButton(
                icon: LucideIcons.arrowRight,
                tooltip: 'رجوع',
                size: 42,
                onPressed: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: JourneySegments(total: total, done: step),
              ),
              const SizedBox(width: 14),
              Text(
                '${step + 1} من $total',
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  weight: JourneyType.bold,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Semantics(
            header: true,
            child: Text(
              question,
              style: JourneyType.of(
                JourneyType.question,
                weight: JourneyType.bold,
                height: 1.25,
              ),
            ),
          ),
        ),
        if (help != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(
              help!,
              style: JourneyType.of(
                JourneyType.bodyLarge,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }
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
    super.key,
  });

  final String label;
  final TextEditingController controller;
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
    final error = widget.errorText;
    final borderColor = error != null
        ? AarastV3Color.danger
        : _focus.hasFocus
        ? context.accent.primary
        : AarastV3Color.line;
    final width = error != null || _focus.hasFocus ? 2.0 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: width),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: AarastV3Color.textMuted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: JourneyType.of(
                        JourneyType.label,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      obscureText: widget.obscureText,
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxLength,
                      textDirection: widget.textDirection,
                      textAlign: widget.textAlign,
                      autofillHints: widget.autofillHints,
                      inputFormatters: widget.inputFormatters,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: JourneyType.of(
                        widget.large ? JourneyType.amount : JourneyType.lead,
                        weight: JourneyType.bold,
                      ),
                      cursorColor: context.accent.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: widget.hint,
                        hintTextDirection: widget.textDirection,
                        // The hint shows the answer as it will look typed.
                        hintStyle: JourneyType.of(
                          widget.large ? JourneyType.amount : JourneyType.lead,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textFaint,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.only(
                          top: 2,
                          bottom: 2,
                        ),
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
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 16,
                  color: AarastV3Color.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error,
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
    super.key,
  });

  final String label;
  final String? value;

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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: note != null ? AarastV3Color.danger : AarastV3Color.line,
            width: note != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AarastV3Color.textMuted),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: JourneyType.of(
                          JourneyType.label,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      Text(
                        has ? value! : placeholder,
                        style: JourneyType.of(
                          JourneyType.lead,
                          weight: JourneyType.bold,
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
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AarastV3Color.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.messageSquare,
                      size: 16,
                      color: AarastV3Color.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.danger,
                          height: 1.45,
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
class JourneyNote extends StatelessWidget {
  const JourneyNote({
    required this.text,
    this.icon = LucideIcons.info,
    this.color,
    this.soft,
    super.key,
  });

  final String text;
  final IconData icon;

  /// The words and fill; the plan's colours when null.
  final Color? color;
  final Color? soft;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.accent.primary;
    final soft = this.soft ?? context.accent.primarySoft;
    return JourneyBox(
      color: soft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: color,
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
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? color : AarastV3Color.line,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const SizedBox.square(
              dimension: 20,
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
