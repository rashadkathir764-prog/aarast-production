import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../utils/guest_display.dart';

/// e01's figures: «86 أكدوا من 124», who has not answered, the three-part
/// bar, and the seats with companions when they are more than the guests
/// who confirmed. The owner's summary card and a participant's read-only
/// guests (D52) draw the same figures.
class GuestSummaryFigures extends StatelessWidget {
  const GuestSummaryFigures({
    required this.words,
    required this.total,
    required this.confirmed,
    required this.pending,
    this.confirmedSeats,
    super.key,
  });

  final GuestWords words;
  final int total;
  final int confirmed;
  final int pending;

  /// Seats with companions; null when not known to the reader.
  /// The seats the confirmed need, their companions counted (RA-MO-59).
  final int? confirmedSeats;

  @override
  Widget build(BuildContext context) {
    // e01's grey is everyone who neither confirmed nor is still waited on.
    final rest = total - confirmed - pending;
    final seats = confirmedSeats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$confirmed',
              style: JourneyType.of(
                JourneyType.count,
                weight: JourneyType.bold,
                height: 1,
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Text(
                '${words.confirmed} من $total',
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
            if (pending > 0)
              // Narrow and large text, it wraps under itself, never off the
              // card.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    // RA-MO-219: the segment holds the invited who did not
                    // reply and the guests no invitation reached yet.
                    '$pending ${words.notYetConfirmed}',
                    textAlign: TextAlign.end,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: AarastV3Color.brandAccentStrong,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AarastV3Radius.xs),
          child: SizedBox(
            key: const ValueKey('guests-summary-bar'),
            height: 10,
            child: Row(
              // Stretch, or the empty pieces would be drawn 0 high.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (count, color) in [
                  (confirmed, context.accent.primary),
                  (pending, AarastV3Color.saffron),
                  (rest, AarastV3Color.line),
                ])
                  if (count > 0)
                    Expanded(
                      flex: count,
                      child: ColoredBox(color: color),
                    ),
              ],
            ),
          ),
        ),
        if (seats != null && seats > confirmed) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            '${words.withCompanions}: ${arabicSeats(seats)}',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
