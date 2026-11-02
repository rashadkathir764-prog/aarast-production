import 'package:flutter/material.dart';

import '../widgets/aarast_bottom_sheet.dart';
import 'aarast_journey.dart';
import 'aarast_v3_foundations.dart';

/// Opens a journey sheet: the prototype's `sheet` shell on the canvas with a
/// 28-point top radius. The builder returns a [JourneySheetBody], which draws
/// the handle, the title and the spacing, so every sheet looks the same.
///
/// Built on [showAarastBottomSheet], so the field being edited lets go first
/// and the sheet stays right to left. The sheet always sizes to its content
/// and scrolls when the content is taller than the screen.
Future<T?> showJourneySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  return showAarastBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AarastV3Color.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(JourneySheetBody.radius),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    useRootNavigator: useRootNavigator,
  );
}

/// The inside of a journey sheet (prototype `sheet`): a 40×5 handle, 14
/// below it the title, an optional muted subtitle, 16 below them the
/// content. Padding 20 / 10 / 20 / 30, where the bottom 30 also covers the
/// phone's own bottom inset. It rises above the keyboard and scrolls, so a
/// tall sheet never overflows. A plain choice of two (camera or gallery)
/// goes without a [title]; [trailing] sits at the far end of the title
/// (a loan's edit button). [bottom] stays under the scrolling content, so a
/// long list keeps its main action in reach.
class JourneySheetBody extends StatelessWidget {
  const JourneySheetBody({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.bottom,
    super.key,
  });

  /// The sheet's top corner radius.
  static const radius = 28.0;

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hasHeading = title != null || subtitle != null;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          Semantics(
            header: true,
            child: Text(
              title,
              style: JourneyType.of(
                JourneyType.sheetTitle,
                weight: JourneyType.bold,
              ),
            ),
          ),
        if (subtitle case final subtitle?)
          Text(
            subtitle,
            style: JourneyType.of(
              JourneyType.bodySmall,
              color: AarastV3Color.textMuted,
            ),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AarastV3Space.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x5,
                  AarastV3Space.x2,
                  AarastV3Space.x5,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _JourneySheetHandle(),
                    if (hasHeading) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      if (trailing case final trailing?)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: AarastV3Space.x2),
                            trailing,
                          ],
                        )
                      else
                        heading,
                    ],
                    const SizedBox(height: AarastV3Space.x4),
                    ...children,
                  ],
                ),
              ),
            ),
            if (bottom case final bottom?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x5,
                  AarastV3Space.x3,
                  AarastV3Space.x5,
                  0,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class _JourneySheetHandle extends StatelessWidget {
  const _JourneySheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('journey-sheet-handle'),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: AarastV3Color.line,
          borderRadius: BorderRadius.circular(AarastV3Radius.xs),
        ),
      ),
    );
  }
}
