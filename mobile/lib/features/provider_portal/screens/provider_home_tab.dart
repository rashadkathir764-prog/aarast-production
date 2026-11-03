import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/offer_ends.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_first_steps.dart';
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_request_parts.dart';

/// p13 «الرئيسية»: who waits for him, who accepted his offer and asks to
/// book, and his confirmed weddings this week. The waiting count is the new
/// requests (SENT and VIEWED), with when the first of them ends (seven days
/// to answer, B-04). Before his first request it is p14
/// ([ProviderFirstSteps]).
class ProviderHomeTab extends StatelessWidget {
  const ProviderHomeTab({required this.onOpenTab, super.key});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x2,
          AarastV3Space.x4,
          AarastV3Density.pageBottom,
        ),
        children: [
          if (profile == null)
            dashboard.isLoading
                ? const JourneyListState(
                    phase: JourneyListPhase.loading,
                    section: JourneySection.home,
                  )
                : JourneyListState(
                    phase: JourneyListPhase.empty,
                    section: JourneySection.home,
                    emptyIcon: LucideIcons.store,
                    emptyTitle: 'كمّل طلب الانضمام',
                    emptyMessage: 'بعد الموافقة تستقبل طلبات العرسان هنا.',
                    emptyAction: 'طلب الانضمام',
                    onEmptyAction: () => context.push(AppRouter.providerApply),
                  )
          else ...[
            const SizedBox(height: AarastV3Space.x2),
            ProviderIdentityRow(
              name: profile.businessName,
              kind: providerKindLine(
                category: profile.primaryCategory?.nameAr,
                city: profile.city?.nameAr,
              ),
              trailing: JourneyRoundButton(
                key: const Key('provider-home-notifications'),
                icon: LucideIcons.bell,
                tooltip: 'التنبيهات',
                onPressed: () => context.push(AppRouter.providerNotifications),
              ),
            ),
            const SizedBox(height: AarastV3Space.x4),
            if (!dashboard.canUseProviderOperations)
              const _ProviderLifecycleNotice()
            else if (dashboard.quoteRequests.isEmpty &&
                dashboard.errorMessage == null &&
                !dashboard.isOffline)
              ProviderFirstSteps(
                dashboard: dashboard,
                onOpenProfile: () => onOpenTab(4),
              )
            else
              ..._operations(context, dashboard),
          ],
          if (dashboard.errorMessage case final error?) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              key: const Key('provider-home-error'),
              text: error,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _operations(
    BuildContext context,
    ProviderDashboardProvider dashboard,
  ) {
    final waiting = dashboard.quoteRequests
        .where((quote) => const {'SENT', 'VIEWED'}.contains(quote.status))
        .toList();
    final asked = dashboard.bookings
        .where((booking) => booking.isRequested)
        .toList();
    final now = appNow();
    final today = DateTime(now.year, now.month, now.day);
    final week =
        dashboard.bookings
            .where(
              (booking) =>
                  booking.isConfirmed &&
                  !booking.eventDate.isBefore(today) &&
                  booking.eventDate.isBefore(
                    today.add(const Duration(days: 7)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return [
      if (waiting.isNotEmpty)
        _WaitingHero(waiting: waiting, onAnswer: () => onOpenTab(1))
      else
        const _NothingWaiting(),
      for (final booking in asked) ...[
        const SizedBox(height: AarastV3Space.x3),
        _BookingAsked(booking: booking, quote: _quoteFor(dashboard, booking)),
      ],
      JourneySectionTitle(
        'هذا الأسبوع',
        action: 'التقويم',
        onAction: () => onOpenTab(2),
      ),
      if (week.isEmpty)
        JourneyBox(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Text(
            'ما عندك عرس مؤكد هذا الأسبوع.',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        )
      else
        JourneyList(
          children: [
            for (final booking in week)
              _weekRow(context, booking, _quoteFor(dashboard, booking)),
          ],
        ),
    ];
  }

  static QuoteRequest? _quoteFor(
    ProviderDashboardProvider dashboard,
    MarketplaceBooking booking,
  ) {
    for (final quote in dashboard.quoteRequests) {
      if (quote.id == booking.quoteRequestId) return quote;
    }
    return null;
  }

  Widget _weekRow(
    BuildContext context,
    MarketplaceBooking booking,
    QuoteRequest? quote,
  ) {
    final name = booking.customerName?.trim().isNotEmpty == true
        ? booking.customerName!.trim()
        : quote == null
        ? 'العميل'
        : providerCustomerName(quote);
    final service = quote?.service?.title.trim() ?? '';
    return JourneyListRow(
      key: Key('provider-home-week-${booking.id}'),
      icon: LucideIcons.calendarCheck,
      color: AarastV3Color.mint,
      soft: AarastV3Color.mintSoft,
      title: formatArabicWeekdayDayMonth(booking.eventDate),
      subtitle: service.isEmpty ? 'عرس $name' : 'عرس $name · $service',
      onTap: () =>
          context.push(AppRouter.providerRequest(booking.quoteRequestId)),
    );
  }
}

/// «ينتظرونك»: how many new requests wait, and since when the oldest.
class _WaitingHero extends StatelessWidget {
  const _WaitingHero({required this.waiting, required this.onAnswer});

  final List<QuoteRequest> waiting;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final count = waiting.length;
    final headline = switch (count) {
      1 => 'طلب ما رديت عليه',
      2 => 'طلبين ما رديت عليهم',
      <= 10 => '$count طلبات ما رديت عليها',
      _ => '$count طلب ما رديت عليها',
    };
    final dates = [for (final quote in waiting) ?quote.createdAt]..sort();
    // B-04: the first of them to end, «ينتهي بعد 6 أيام».
    final deadlines = [for (final quote in waiting) ?quote.expiresAt]..sort();
    final ends = deadlines.isEmpty
        ? null
        : offerEndsLabel(deadlines.first.toLocal(), appNow());
    final arrived = dates.isEmpty
        ? null
        : count == 1
        ? 'وصل ${providerDayLabel(dates.first)}'
        : 'أقدمها من ${providerDayLabel(dates.first)}';
    final since = [?arrived, ?ends].join(' · ');
    return Container(
      key: const Key('provider-home-waiting'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      decoration: BoxDecoration(
        color: AarastV3Color.primary,
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ينتظرونك',
            style: JourneyType.of(
              JourneyType.bodySmall,
              color: AarastV3Color.onPrimaryMuted,
            ),
          ),
          Text(
            headline,
            style: JourneyType.of(
              JourneyType.sheetTitle,
              weight: JourneyType.bold,
              color: AarastV3Color.onPrimary,
            ),
          ),
          if (since.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              since,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.onPrimaryMuted,
              ),
            ),
          ],
          const SizedBox(height: AarastV3Space.x3),
          JourneyButton(
            key: const Key('provider-home-answer'),
            label: 'ردّ الآن',
            background: AarastV3Color.paper,
            foreground: AarastV3Color.primary,
            large: true,
            onPressed: onAnswer,
          ),
        ],
      ),
    );
  }
}

/// No new request waits, though requests came before.
class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const Key('provider-home-none-waiting'),
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.inbox,
            color: AarastV3Color.primary,
            soft: AarastV3Color.primarySoft,
            size: 42,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ما فيه طلب ينتظر ردك',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  'الطلبات الجديدة توصلك هنا.',
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
    );
  }
}

/// «محمد قبل عرضك · أكّد»: a booking request waiting for his confirmation.
/// There is no confirmation deadline, so «أكّد اليوم» is not said.
class _BookingAsked extends StatelessWidget {
  const _BookingAsked({required this.booking, required this.quote});

  final MarketplaceBooking booking;
  final QuoteRequest? quote;

  @override
  Widget build(BuildContext context) {
    final name = booking.customerName?.trim().isNotEmpty == true
        ? booking.customerName!.trim()
        : quote == null
        ? 'العميل'
        : providerCustomerName(quote!);
    void open() =>
        context.push(AppRouter.providerRequest(booking.quoteRequestId));
    return JourneyBox(
      key: Key('provider-home-booking-${booking.id}'),
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.calendarCheck,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: 42,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${providerFirstName(name)} قبل عرضك',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  'يشتي يحجز ${formatArabicWeekdayDayMonth(booking.eventDate)}',
                  style: JourneyType.of(
                    JourneyType.label,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          JourneyButton(
            key: Key('provider-home-confirm-${booking.id}'),
            label: 'أكّد',
            background: AarastV3Color.brandAccentSoft,
            foreground: AarastV3Color.brandAccentStrong,
            onPressed: open,
          ),
        ],
      ),
    );
  }
}

/// The server refused his operations although the profile read as active
/// (its status changed meanwhile). Every other status has its own screen
/// (p08, p09, p11, p12), so this only asks for a refresh and offers support.
class _ProviderLifecycleNotice extends StatelessWidget {
  const _ProviderLifecycleNotice();

  @override
  Widget build(BuildContext context) {
    const title = 'شغل المزود موقوف الآن';
    const message = 'اسحب الصفحة لتحت عشان تتحدّث حالة حسابك.';
    return JourneyBox(
      key: const Key('provider-lifecycle-notice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const JourneyIconTile(
                icon: LucideIcons.shieldAlert,
                color: AarastV3Color.brandAccentStrong,
                soft: AarastV3Color.brandAccentSoft,
                size: 42,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            message,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            key: const Key('provider-lifecycle-support'),
            label: 'تواصل مع الدعم',
            icon: LucideIcons.lifeBuoy,
            background: AarastV3Color.primarySoft,
            foreground: AarastV3Color.primary,
            expand: true,
            onPressed: () => context.push(AppRouter.support),
          ),
        ],
      ),
    );
  }
}
