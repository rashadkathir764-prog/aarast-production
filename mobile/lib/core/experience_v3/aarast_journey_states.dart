import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'aarast_journey.dart';
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
    this.emptyAction,
    this.onEmptyAction,
    this.onRetry,
    this.emptyIcon,
    super.key,
  });

  final JourneyListPhase phase;
  final JourneySection section;

  /// «ما أضفت ضيوف».
  final String? emptyTitle;

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
                if (index > 0) const SizedBox(height: 10),
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
        section.color,
        section.soft,
        emptyTitle ?? 'ما في شي بعد',
        emptyAction,
        onEmptyAction,
      ),
      JourneyListPhase.error => (
        LucideIcons.alertTriangle,
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
        'ما قدرنا نجيبها',
        onRetry == null ? null : 'حاول مرة ثانية',
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
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
  const JourneyListNotice({required this.offline, this.onRetry, super.key});

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
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(16),
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
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    offline
                        ? 'آخر نسخة محفوظة · تشوف بس'
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
                label: 'حاول مرة ثانية',
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
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
