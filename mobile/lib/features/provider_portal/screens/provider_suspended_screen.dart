import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p12 «حسابك موقوف مؤقتًا»: since when, why, and the confirmed bookings
/// that go on. The count is the upcoming CONFIRMED bookings from the
/// bookings list, which the server still serves a suspended provider (F10).
class ProviderSuspendedScreen extends StatelessWidget {
  const ProviderSuspendedScreen({
    required this.profile,
    required this.upcoming,
    required this.bookingsKnown,
    required this.onRefresh,
    required this.onSupport,
    required this.onAccount,
    super.key,
  });

  final ProviderDashboardProfile profile;

  /// Upcoming confirmed bookings, nearest first; read only when
  /// [bookingsKnown].
  final List<MarketplaceBooking> upcoming;
  final bool bookingsKnown;

  int get upcomingBookings => upcoming.length;

  /// «افتح حجوزاتك»: the weddings ahead, each with its day. A suspended
  /// provider reads only his bookings (F10), not their requests, so the
  /// list is the booking's own name, day and guests.
  void _openBookings(BuildContext context) {
    showJourneySheet<void>(
      context: context,
      builder: (_) => JourneySheetBody(
        title: 'حجوزاتك الجاية',
        children: [
          JourneyList(
            children: [
              for (final booking in upcoming)
                JourneyListRow(
                  key: Key('provider-suspended-booking-${booking.id}'),
                  icon: LucideIcons.calendarCheck,
                  color: AarastV3Color.mint,
                  soft: AarastV3Color.mintSoft,
                  title: booking.customerName?.trim().isNotEmpty == true
                      ? booking.customerName!.trim()
                      : 'حجز مؤكد',
                  subtitle: [
                    formatArabicWeekdayDayMonth(booking.eventDate),
                    if (booking.guestCount case final guests? when guests > 0)
                      '${arabicCount(guests, one: 'ضيف واحد', two: 'ضيفين', few: 'ضيوف', many: 'ضيف')} تقريبًا',
                  ].join(' · '),
                ),
            ],
          ),
        ],
      ),
    );
  }

  final Future<void> Function() onRefresh;
  final VoidCallback onSupport;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final since = profile.reviewedAt;
    final reason = profile.reviewNote?.trim() ?? '';
    final showBookings = !bookingsKnown || upcomingBookings > 0;
    const keep = 'العرسان معتمدين عليك، كمّلها.';
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [
                  ProviderStateHeading(
                    name: profile.businessName,
                    kind: providerKindLine(
                      category: profile.primaryCategory?.nameAr,
                      city: profile.city?.nameAr,
                    ),
                    icon: LucideIcons.pauseOctagon,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                    title: 'حسابك موقوف مؤقتًا',
                    message: since == null
                        ? 'ما توصلك طلبات جديدة لين ينحل الموضوع.'
                        : 'من ${providerDayLabel(since)}. ما توصلك طلبات جديدة لين ينحل الموضوع.',
                    trailing: ProviderAccountButton(onPressed: onAccount),
                  ),
                  if (reason.isNotEmpty) ...[
                    JourneyBox(
                      key: const Key('provider-suspended-reason'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السبب',
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                          Text(
                            reason,
                            style: JourneyType.of(
                              JourneyType.body,
                              weight: JourneyType.bold,
                              height: AarastV3Line.reading,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                  ],
                  if (showBookings)
                    JourneyBox(
                      key: const Key('provider-suspended-bookings'),
                      color: AarastV3Color.mintSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حجوزاتك المؤكدة مستمرة',
                            style: JourneyType.of(
                              JourneyType.body,
                              weight: JourneyType.bold,
                              color: AarastV3Color.mint,
                            ),
                          ),
                          Text(
                            bookingsKnown
                                ? '${_weddings(upcomingBookings)}. $keep'
                                : keep,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.mint,
                            ),
                          ),
                          // «كمّلها» needs a way to them: which weddings,
                          // and on which day.
                          if (bookingsKnown && upcoming.isNotEmpty) ...[
                            const SizedBox(height: AarastV3Space.x3),
                            JourneyButton(
                              key: const Key(
                                'provider-suspended-open-bookings',
                              ),
                              label: 'افتح حجوزاتك',
                              icon: LucideIcons.calendarCheck,
                              background: AarastV3Color.paper,
                              foreground: AarastV3Color.mint,
                              expand: true,
                              onPressed: () => _openBookings(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-suspended-support'),
              label: 'التواصل مع الدعم',
              icon: LucideIcons.messageCircle,
              expand: true,
              large: true,
              onPressed: onSupport,
            ),
          ),
        ],
      ),
    );
  }
}

/// «5 أعراس جاية».
String _weddings(int count) => arabicCount(
  count,
  one: 'عرس واحد جاي',
  two: 'عرسين جايين',
  few: 'أعراس جاية',
  many: 'عرس جاي',
);
