import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'aarast_journey.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

// w42: every list has the same four states, in its section's colour. An
// error never wipes what is already shown: a list with rows keeps them and
// shows [JourneyListNotice] above them; only an empty list shows the full
// error state.

/// Which of the four states a list is in.
enum JourneyListPhase { loading, empty, error, offline }

/// A list's whole-area state when it has no rows to show.
class JourneyListState extends StatelessWidget {
  const JourneyListState({
    required this.phase,
    required this.section,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyAction,
    this.onEmptyAction,
    this.onRetry,
    this.emptyIcon,
    this.errorMessage,
    super.key,
  });

  /// D88: why it could not be read, as measured (D84), under the title.
  final String? errorMessage;

  final JourneyListPhase phase;
  final JourneySection section;

  /// «ما أضفت ضيوف».
  final String? emptyTitle;

  /// Why it is empty, under the title.
  final String? emptyMessage;

  /// «أضف أول ضيف».
  final String? emptyAction;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onRetry;
  final IconData? emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (phase == JourneyListPhase.loading) {
      return Semantics(
        label: 'يحمّل',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Column(
            key: const ValueKey('journey-list-loading'),
            children: [
              for (var index = 0; index < 4; index++) ...[
                if (index > 0) const SizedBox(height: AarastV3Space.x2),
                const _LoadingRow(),
              ],
            ],
          ),
        ),
      );
    }

    final (icon, color, soft, title, action, onAction) = switch (phase) {
      JourneyListPhase.empty => (
        emptyIcon ?? section.icon,
        section.colorOf(context),
        section.softOf(context),
        emptyTitle ?? 'ما في شي بعد',
        emptyAction,
        onEmptyAction,
      ),
      JourneyListPhase.error => (
        LucideIcons.alertTriangle,
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
        'ما قدرنا نجيبها',
        onRetry == null
            ? null
            : context.say('حاول مرة ثانية', 'حاولي مرة ثانية'),
        onRetry,
      ),
      _ => (
        LucideIcons.wifiOff,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        'ما في نت، وما عندك نسخة محفوظة',
        null,
        null,
      ),
    };

    return Padding(
      key: ValueKey('journey-list-${phase.name}'),
      padding: const EdgeInsets.symmetric(
        vertical: AarastV3Space.x8,
        horizontal: AarastV3Space.x4,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(AarastV3Radius.card),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: AarastV3Space.x3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
            ),
          ),
          if (phase == JourneyListPhase.error && errorMessage != null ||
              phase == JourneyListPhase.empty && emptyMessage != null) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              phase == JourneyListPhase.error ? errorMessage! : emptyMessage!,
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyButton(
              label: action,
              background: soft,
              foreground: color,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Above a list that still has rows: why they may be old, and a retry.
class JourneyListNotice extends StatelessWidget {
  const JourneyListNotice({
    required this.offline,
    this.onRetry,
    this.keepsChanges = false,
    super.key,
  });

  /// D89: this section's changes queue on the phone (D85), so the old copy
  /// is not «تشوف بس».
  final bool keepsChanges;

  /// Offline shows «آخر نسخة محفوظة · تشوف بس»; otherwise the load failed.
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = offline ? AarastV3Color.textMuted : AarastV3Color.danger;
    final soft = offline ? AarastV3Color.line : AarastV3Color.dangerSoft;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey('journey-list-notice-${offline ? 'offline' : 'error'}'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AarastV3Space.x3,
          AarastV3Space.x2,
          AarastV3Space.x1,
          AarastV3Space.x2,
        ),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        ),
        child: Wrap(
          // The retry drops under the line when large text needs the room.
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offline ? LucideIcons.wifiOff : LucideIcons.alertTriangle,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Flexible(
                  child: Text(
                    offline
                        ? context.say(
                            keepsChanges
                                ? 'آخر نسخة محفوظة · تغييراتك تنحفظ في جوالك'
                                : 'آخر نسخة محفوظة · تشوف بس',
                            keepsChanges
                                ? 'آخر نسخة محفوظة · تغييراتك تنحفظ في جوالك'
                                : 'آخر نسخة محفوظة · تشوفين بس',
                          )
                        : 'ما قدرنا نحدّثها، وهذي آخر نسخة',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null && !offline)
              JourneyTextAction(
                label: context.say('حاول مرة ثانية', 'حاولي مرة ثانية'),
                color: color,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AarastV3Color.line,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
    );
  }
}
