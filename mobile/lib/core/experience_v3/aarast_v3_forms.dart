import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../forms/aarast_form_draft_store.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

class AarastV3DraftStatusLine extends StatelessWidget {
  const AarastV3DraftStatusLine({required this.status, super.key});

  final AarastFormDraftStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      AarastFormDraftStatus.saving => (
        LucideIcons.loader2,
        'جارٍ حفظ المسودة…',
        AarastV3Color.textMuted,
      ),
      AarastFormDraftStatus.saved => (
        LucideIcons.check,
        'حُفظت المسودة تلقائيًا',
        AarastV3Color.mint,
      ),
      AarastFormDraftStatus.failed => (
        LucideIcons.alertCircle,
        'تعذر حفظ المسودة على الجهاز',
        AarastV3Color.rose,
      ),
      AarastFormDraftStatus.idle => (
        LucideIcons.shieldCheck,
        'ستُحفظ قيمك تلقائيًا',
        AarastV3Color.textMuted,
      ),
    };
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      liveRegion: status == AarastFormDraftStatus.saved,
      label: label,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        child: Row(
          key: ValueKey(status),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AarastV3Space.x2),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AarastV3FocusPrompt extends StatelessWidget {
  const AarastV3FocusPrompt({
    required this.question,
    required this.supportingText,
    this.eyebrow = 'القرار الأساسي',
    this.icon = LucideIcons.target,
    super.key,
  });

  final String eyebrow;
  final String question;
  final String supportingText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: AarastV3Space.x2,
          top: AarastV3Space.x1,
          bottom: AarastV3Space.x1,
        ),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: context.accent.primary, width: 2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.accent.primary, size: 17),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: AarastV3Type.label(
                      context,
                    ).copyWith(color: context.accent.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(question, style: AarastV3Type.section(context)),
                  const SizedBox(height: 2),
                  Text(
                    supportingText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AarastV3Type.body(context).copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AarastV3SummaryItem {
  const AarastV3SummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}

class AarastV3LiveSummary extends StatelessWidget {
  const AarastV3LiveSummary({
    required this.items,
    this.title = 'ملخص حي',
    super.key,
  });

  final String title;
  final List<AarastV3SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AarastV3Color.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AarastV3Type.label(
              context,
            ).copyWith(color: context.accent.primary),
          ),
          const SizedBox(height: AarastV3Space.x1),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 380 ? 3 : 2;
              final width =
                  (constraints.maxWidth - ((columns - 1) * AarastV3Space.x2)) /
                  columns;
              return Wrap(
                spacing: AarastV3Space.x2,
                runSpacing: AarastV3Space.x2,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AarastV3Color.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AarastV3Color.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AarastV3FormActionBar extends StatelessWidget {
  const AarastV3FormActionBar({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.maxWidth = 560,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AarastV3Color.paper,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AarastV3Color.line)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            AarastV3Space.x2,
            AarastV3Space.x4,
            AarastV3Space.x2,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AarastV3PrimaryAction(
                label: label,
                icon: icon,
                loading: loading,
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AarastV3BottomSheetFormLayout extends StatelessWidget {
  const AarastV3BottomSheetFormLayout({
    required this.header,
    required this.child,
    required this.action,
    super.key,
  });

  final Widget header;
  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * .88;
    final visibleHeight = (maxHeight - media.viewInsets.bottom).clamp(
      180.0,
      maxHeight,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: visibleHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  AarastV3Space.x1,
                  AarastV3Space.x4,
                  0,
                ),
                child: header,
              ),
              const SizedBox(height: AarastV3Space.x2),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AarastV3Space.x4,
                    0,
                    AarastV3Space.x4,
                    AarastV3Space.x3,
                  ),
                  child: child,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  AarastV3Space.x2,
                  AarastV3Space.x4,
                  AarastV3Space.x2,
                ),
                decoration: const BoxDecoration(
                  color: AarastV3Color.paper,
                  border: Border(top: BorderSide(color: AarastV3Color.line)),
                ),
                child: action,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AarastV3FormSurface extends StatelessWidget {
  const AarastV3FormSurface({
    required this.children,
    this.title,
    this.subtitle,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: subtitle == null ? 26 : 46,
                  color: context.accent.primary,
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: AarastV3Type.section(context)),
                      if (subtitle != null) ...[
                        const SizedBox(height: AarastV3Space.x1),
                        Text(subtitle!, style: AarastV3Type.body(context)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AarastV3Space.x3),
          ],
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: AarastV3Space.x2),
          ],
        ],
      ),
    );
  }
}

class AarastV3Disclosure extends StatelessWidget {
  const AarastV3Disclosure({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = LucideIcons.slidersHorizontal,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool initiallyExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: const Border.symmetric(
          horizontal: BorderSide(color: AarastV3Color.line),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x2),
          childrenPadding: const EdgeInsets.fromLTRB(
            AarastV3Space.x2,
            0,
            AarastV3Space.x2,
            AarastV3Space.x2,
          ),
          leading: Icon(icon, color: context.accent.primary, size: 19),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AarastV3Color.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AarastV3Color.textMuted,
                  ),
                ),
          children: [child],
        ),
      ),
    );
  }
}

class AarastV3PrimaryAction extends StatelessWidget {
  const AarastV3PrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: context.accent.primary,
        foregroundColor: AarastV3Color.onPrimary,
        disabledBackgroundColor: AarastV3Color.lineStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AarastV3Color.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19),
                  const SizedBox(width: AarastV3Space.x2),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AarastV3Color.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
