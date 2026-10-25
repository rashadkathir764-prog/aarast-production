import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_booking_sheets.dart'
    show ProviderConfirmNeedsNetwork;
import '../widgets/provider_quick_offer_sheet.dart';
import '../widgets/provider_request_cards.dart';
import '../widgets/provider_request_parts.dart';

export 'provider_offer_screen.dart' show validateProviderOfferAmount;

/// A request with where it stands, read once per build.
typedef ProviderCase = ({
  QuoteRequest quote,
  MarketplaceBooking? booking,
  ProviderCaseState state,
});

/// Every request the provider holds, with its state.
List<ProviderCase> providerCases(ProviderDashboardProvider dashboard) => [
  for (final quote in dashboard.quoteRequests)
    () {
      final booking = providerBookingOf(quote, dashboard);
      return (
        quote: quote,
        booking: booking,
        state: providerCaseOf(quote, booking),
      );
    }(),
];

/// How many new requests wait for his answer (SENT and VIEWED): the
/// requests tab's badge, p13's «ينتظرونك» and p15's line, as drawn. The
/// bookings to confirm sit in the same list without adding to the count.
int providerWaitingCount(ProviderDashboardProvider dashboard) => dashboard
    .quoteRequests
    .where((quote) => const {'SENT', 'VIEWED'}.contains(quote.status))
    .length;

/// p15 «الطلبات» and, on its last list, p20 «انتهى». The lists are read on
/// the phone from every request the server sends (F5): new, answered,
/// booked and ended. No time left is shown (F8) and no occasion (the
/// server holds none).
class ProviderRequestsTab extends StatefulWidget {
  const ProviderRequestsTab({super.key});

  @override
  State<ProviderRequestsTab> createState() => _ProviderRequestsTabState();
}

class _ProviderRequestsTabState extends State<ProviderRequestsTab> {
  ProviderRequestTab _tab = ProviderRequestTab.fresh;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final cases = providerCases(dashboard);
    int count(ProviderRequestTab tab) =>
        cases.where((item) => item.state.tab == tab).length;
    final waiting = providerWaitingCount(dashboard);
    final shown = _sorted(
      cases.where((item) => item.state.tab == _tab).toList(),
    );
    final offline = dashboard.isOffline;
    final updated = dashboard.lastUpdatedAt;
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
        children: [
          JourneyTabHeader(
            title: 'الطلبات',
            status: _tab == ProviderRequestTab.ended
                ? 'اللي ما كمّل، وليش'
                : waiting == 0
                ? 'ما فيه أحد ينتظر ردك'
                : '$waiting ينتظرون ردك',
          ),
          // p43: without the network the lists are the last ones read,
          // a new offer waits on the phone, and a confirmation waits for
          // the network.
          if (offline) ...[
            const ProviderOfflineBar(),
            const SizedBox(height: 14),
          ],
          if (dashboard.droppedOffers.isNotEmpty) ...[
            ProviderDroppedOffersBox(
              key: const Key('provider-dropped-offers'),
              lines: [
                for (final dropped in dashboard.droppedOffers)
                  providerDroppedOfferLine(
                    dropped,
                    _queuedName(cases, dropped.quoteRequestId),
                  ),
              ],
              onDismiss: dashboard.dismissDroppedOffers,
            ),
            const SizedBox(height: 10),
          ],
          for (final offer in dashboard.queuedOffers) ...[
            ProviderQueuedOfferBox(
              key: Key('provider-queued-offer-${offer.quoteRequestId}'),
              name: _queuedName(cases, offer.quoteRequestId),
            ),
            const SizedBox(height: 10),
          ],
          if (offline &&
              cases.any(
                (item) => item.state == ProviderCaseState.bookingAsked,
              )) ...[
            const ProviderConfirmNeedsNetwork(),
            const SizedBox(height: 10),
          ],
          if (offline && updated != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                providerUpdatedLabel(updated),
                key: const Key('provider-requests-updated'),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // One line as drawn; a large text size wraps it, never hides one.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in ProviderRequestTab.values)
                JourneyChip(
                  key: Key('provider-requests-tab-${tab.name}'),
                  // The ended list carries no count, as drawn.
                  label: switch (tab) {
                    ProviderRequestTab.ended => tab.label,
                    ProviderRequestTab.fresh when waiting > 0 =>
                      '${tab.label} $waiting',
                    ProviderRequestTab.fresh => tab.label,
                    _ when count(tab) > 0 => '${tab.label} ${count(tab)}',
                    _ => tab.label,
                  },
                  selected: _tab == tab,
                  onTap: () => setState(() => _tab = tab),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            JourneyListState(
              phase: dashboard.isLoading && dashboard.quoteRequests.isEmpty
                  ? JourneyListPhase.loading
                  : dashboard.errorMessage != null &&
                        dashboard.quoteRequests.isEmpty
                  ? JourneyListPhase.error
                  : JourneyListPhase.empty,
              section: JourneySection.home,
              emptyIcon: JourneySection.home.icon,
              emptyTitle: switch (_tab) {
                ProviderRequestTab.fresh => 'ما فيه طلب جديد',
                ProviderRequestTab.replied => 'ما فيه عرض ينتظر رد',
                ProviderRequestTab.booked => 'ما عندك حجز لسا',
                ProviderRequestTab.ended => 'ما فيه شيء انتهى',
              },
              emptyMessage: _tab == ProviderRequestTab.fresh
                  ? 'الطلبات الجديدة توصلك هنا.'
                  : null,
              onRetry: dashboard.loadDashboard,
            )
          else
            for (var index = 0; index < shown.length; index++) ...[
              if (index > 0)
                SizedBox(height: _tab == ProviderRequestTab.ended ? 12 : 10),
              _card(context, dashboard, shown[index], index),
            ],
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    ProviderDashboardProvider dashboard,
    ProviderCase item,
    int index,
  ) {
    final quote = item.quote;
    void open() => context.push(AppRouter.providerRequest(quote.id));
    if (_tab == ProviderRequestTab.ended) {
      return ProviderEndedCard(
        quote: quote,
        state: item.state,
        booking: item.booking,
        onOpen: open,
        onRenew: item.state == ProviderCaseState.offerExpired
            ? () => context.push(AppRouter.providerRequestOffer(quote.id))
            : null,
      );
    }
    final packages = item.state == ProviderCaseState.fresh
        ? providerOfferPackages(dashboard.packages, quote)
        : const <Never>[];
    return ProviderRequestCard(
      quote: quote,
      state: item.state,
      booking: item.booking,
      color: JourneyAvatar.paletteAt(context, index + 1),
      onOpen: open,
      onQuickOffer: packages.isEmpty
          ? null
          : () => showProviderQuickOffer(context, quote, packages),
    );
  }

  static String _queuedName(List<ProviderCase> cases, String quoteId) {
    for (final item in cases) {
      if (item.quote.id == quoteId) {
        return providerFirstName(providerCustomerName(item.quote));
      }
    }
    return 'العميل';
  }

  /// New requests oldest first (the one waiting longest on top), then the
  /// bookings to confirm; the rest by their latest change.
  List<ProviderCase> _sorted(List<ProviderCase> items) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    int rank(ProviderCase item) =>
        item.state == ProviderCaseState.fresh ? 0 : 1;
    return items..sort((a, b) {
      if (_tab == ProviderRequestTab.fresh) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return (a.quote.createdAt ?? epoch).compareTo(
          b.quote.createdAt ?? epoch,
        );
      }
      if (_tab == ProviderRequestTab.booked) {
        return (a.booking?.eventDate ?? epoch).compareTo(
          b.booking?.eventDate ?? epoch,
        );
      }
      return (b.quote.updatedAt ?? epoch).compareTo(a.quote.updatedAt ?? epoch);
    });
  }
}
