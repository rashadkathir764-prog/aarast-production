import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../widgets/provider_join_parts.dart';

/// p12 «حسابك موقوف مؤقتًا»: since when, why, and the confirmed bookings
/// that go on. The count is the upcoming CONFIRMED bookings from the
/// bookings list, which the server still serves a suspended provider (F10).
class ProviderSuspendedScreen extends StatelessWidget {
  const ProviderSuspendedScreen({
    required this.profile,
    required this.upcomingBookings,
    required this.bookingsKnown,
    required this.onRefresh,
    required this.onSupport,
    required this.onAccount,
    super.key,
  });

  final ProviderDashboardProfile profile;

  /// Upcoming confirmed bookings; read only when [bookingsKnown].
  final int upcomingBookings;
  final bool bookingsKnown;
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
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              JourneyType.detail,
                              color: AarastV3Color.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: JourneyButton(
              key: const Key('provider-suspended-support'),
              label: 'تكلّم مع الدعم',
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
