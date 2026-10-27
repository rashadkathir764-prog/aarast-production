import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../wedding_plans/wedding_plans_api.dart' show PlanReadBooking;
import 'provider_board_view.dart' show providerServiceIcon;

/// q16's card: the plan's bookings, each with its service icon, the
/// provider, the day (or «ينتظر تأكيدهم») and «محجوز» / «ينتظر». No price,
/// no offer, no phone (D52).
class PlanReadBookingsCard extends StatelessWidget {
  const PlanReadBookingsCard({required this.bookings, super.key});

  final List<PlanReadBooking> bookings;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('plan-read-bookings'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, booking) in bookings.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 76,
                endIndent: 14,
                color: AarastV3Color.line,
              ),
            _BookingLine(
              key: ValueKey('plan-read-booking-${booking.id}'),
              booking: booking,
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingLine extends StatelessWidget {
  const _BookingLine({required this.booking, super.key});

  final PlanReadBooking booking;

  @override
  Widget build(BuildContext context) {
    final day = booking.eventDate;
    final line = booking.confirmed
        ? (day == null ? 'محجوز' : formatArabicWeekdayDayMonth(day))
        : 'ينتظر تأكيدهم';
    final name = booking.businessName.isEmpty ? 'مزود' : booking.businessName;
    final service = booking.serviceTitle ?? booking.categoryName ?? name;
    return Semantics(
      label: '$name، $line، ${booking.confirmed ? 'محجوز' : 'ينتظر'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            JourneyIconTile(
              icon: providerServiceIcon(
                [
                  booking.categoryName,
                  booking.serviceTitle,
                  service,
                ].whereType<String>().join(' '),
              ),
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    line,
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
            const SizedBox(width: 8),
            booking.confirmed
                ? const JourneyTag(
                    label: 'محجوز',
                    color: AarastV3Color.mint,
                    soft: AarastV3Color.mintSoft,
                  )
                : const JourneyTag(
                    label: 'ينتظر',
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
          ],
        ),
      ),
    );
  }
}
