import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_booking_sheets.dart';
import '../widgets/provider_decline_sheet.dart';
import '../widgets/provider_join_parts.dart'
    show providerDayLabel, providerMomentLabel;
import '../widgets/provider_request_cards.dart' show ProviderEndedCard;
import '../widgets/provider_request_parts.dart';
import '../widgets/provider_withdraw_sheet.dart';
import 'provider_booking_screen.dart';

/// One request as the provider sees it. A new one (SENT or VIEWED) is p16
/// «طلب جديد»: the facts the server holds, his own day, the message, and
/// the offer or the apology. Once he answered it is p19: his offer, its end
/// date, and its edit or renewal; a booking request opens p21 over it once.
/// A confirmed booking is p22, and one cancelled or declined p25. Opening a
/// new request tells the customer it was seen, once (D35).
class ProviderRequestScreen extends StatefulWidget {
  const ProviderRequestScreen({required this.quoteId, super.key});

  final String quoteId;

  @override
  State<ProviderRequestScreen> createState() => _ProviderRequestScreenState();
}

class _ProviderRequestScreenState extends State<ProviderRequestScreen> {
  /// The booking requests whose p21 sheet already opened here.
  final _confirmShown = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final dashboard = context.read<ProviderDashboardProvider>();
      // A link straight to the request reads the requests first.
      if (_quoteOf(dashboard) == null && !dashboard.isLoading) {
        await dashboard.loadDashboard();
      }
      if (!mounted) return;
      dashboard.markQuoteViewed(widget.quoteId);
    });
  }

  QuoteRequest? _quoteOf(ProviderDashboardProvider dashboard) {
    for (final quote in dashboard.quoteRequests) {
      if (quote.id == widget.quoteId) return quote;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final quote = _quoteOf(dashboard);
    if (quote == null) {
      return AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const JourneySubHeader(title: 'الطلب'),
            JourneyListState(
              phase: dashboard.isLoading
                  ? JourneyListPhase.loading
                  : JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: dashboard.loadDashboard,
            ),
          ],
        ),
      );
    }
    final booking = providerBookingOf(quote, dashboard);
    final state = providerCaseOf(quote, booking);
    switch (state) {
      case ProviderCaseState.fresh:
        return _NewRequest(quote: quote, dashboard: dashboard);
      case ProviderCaseState.booked || ProviderCaseState.done:
        return ProviderBookingScreen(quote: quote, booking: booking!);
      case ProviderCaseState.bookingCancelled ||
          ProviderCaseState.bookingDeclined:
        return ProviderBookingEndedScreen(quote: quote, booking: booking!);
      case ProviderCaseState.bookingAsked:
        // As drawn, the request opens with p21 on it, once.
        if (_confirmShown.add(booking!.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showProviderConfirmSheet(context, quote: quote, booking: booking);
          });
        }
      default:
        break;
    }
    return _Answered(quote: quote, state: state, dashboard: dashboard);
  }
}

/// p16 «طلب جديد».
class _NewRequest extends StatelessWidget {
  const _NewRequest({required this.quote, required this.dashboard});

  final QuoteRequest quote;
  final ProviderDashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final name = providerCustomerName(quote);
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final message = quote.message?.trim() ?? '';
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                JourneySubHeader(
                  title: 'طلب جديد',
                  subtitle: quote.createdAt == null
                      ? null
                      : 'وصل ${providerMomentLabel(quote.createdAt!)}',
                ),
                Row(
                  children: [
                    JourneyAvatar(
                      letter: name.characters.first,
                      color: AarastV3Color.primary,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: JourneyType.of(
                          JourneyType.lead,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // No «لم يحدد الموقع» filler: an empty fact is left out.
                ProviderRequestFacts(quote: quote, showHijri: showHijri),
                const SizedBox(height: 10),
                if (message.isNotEmpty) ...[
                  JourneyBox(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '«$message»',
                      style: JourneyType.of(JourneyType.body, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // p43: his offer waits on the phone for the network.
                if (dashboard.queuedOfferFor(quote.id) != null) ...[
                  ProviderQueuedOfferBox(
                    key: const Key('provider-request-queued-offer'),
                    name: providerFirstName(name),
                  ),
                  const SizedBox(height: 10),
                ],
                // B-03: he took his offer back; the request waits for him.
                if (quote.withdrawnOffer case final withdrawn?) ...[
                  JourneyNote(
                    key: const Key('provider-request-withdrawn'),
                    text: _withdrawnLine(withdrawn.withdrawnAt, quote.expiresAt),
                  ),
                  const SizedBox(height: 10),
                ],
                if (quote.eventDate case final day?) ...[
                  ProviderDayStatus(
                    day: day,
                    dashboard: dashboard,
                    quoteId: quote.id,
                  ),
                  const SizedBox(height: 8),
                ],
                // p16, B-08: what the customer did not share stays his.
                if (_privacyLine(quote) case final privacy?)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      privacy,
                      key: const Key('provider-request-privacy'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                Center(
                  child: JourneyTextAction(
                    key: const Key('provider-request-ask'),
                    // D55: the customer's gender is not known to the
                    // provider's words, so p16's «اسأله» names no one.
                    label: 'اسأل قبل ما ترد',
                    color: AarastV3Color.primary,
                    onPressed: () =>
                        context.push(AppRouter.quoteConversation(quote.id)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: JourneyButton(
                    key: const Key('provider-request-offer'),
                    label: 'أرسل عرض',
                    expand: true,
                    large: true,
                    onPressed: () =>
                        context.push(AppRouter.providerRequestOffer(quote.id)),
                  ),
                ),
                const SizedBox(width: 10),
                JourneyButton(
                  key: Key('provider-quote-decline-${quote.id}'),
                  label: 'اعتذر',
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.textMuted,
                  large: true,
                  onPressed: () => _decline(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// «سحبت عرضك أمس. أرسل عرض جديد أو اعتذر قبل 29 أكتوبر.»
  static String _withdrawnLine(DateTime? withdrawnAt, DateTime? expiresAt) {
    final when = withdrawnAt == null ? '' : ' ${providerDayLabel(withdrawnAt)}';
    final until = expiresAt == null
        ? ''
        : ' قبل ${formatArabicDayMonth(expiresAt.toLocal())}';
    return 'سحبت عرضك$when. أرسل عرض جديد أو اعتذر$until.';
  }

  /// The line under p16's facts, naming only what he does not have.
  static String? _privacyLine(QuoteRequest quote) {
    return switch ((quote.shareBudget, quote.shareContact)) {
      (false, false) =>
        'ميزانيته ورقمه ما يوصلونك إلا إذا شاركهم. تكلّم معه من «اسأل».',
      (true, false) => 'رقمه ما يوصلك إلا إذا شاركه. تكلّم معه من «اسأل».',
      (false, true) => 'ميزانيته ما توصلك إلا إذا شاركها.',
      (true, true) => null,
    };
  }

  Future<void> _decline(BuildContext context) async {
    final declined = await showProviderDeclineSheet(context, quote);
    if (!declined || !context.mounted) return;
    // A request opened from a link has no list under it.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.providerRequestsTab);
    }
  }
}

/// p19: the answered request, his offer and what can still change.
class _Answered extends StatelessWidget {
  const _Answered({
    required this.quote,
    required this.state,
    required this.dashboard,
  });

  final QuoteRequest quote;
  final ProviderCaseState state;
  final ProviderDashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final booking = providerBookingOf(quote, dashboard);
    final offer =
        quote.acceptedOffer ??
        quote.pendingOffer ??
        quote.expiredOffer ??
        (quote.offers.isEmpty ? null : quote.offers.last);
    // The server lets him change a pending offer, expired or not, while the
    // request waits for the customer (D35).
    final canChange =
        quote.status.toUpperCase() == 'RESPONDED' &&
        (quote.pendingOffer != null || quote.expiredOffer != null);
    final renew = quote.pendingOffer == null && quote.expiredOffer != null;
    final line = providerRequestLine(quote);
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: providerCustomerName(quote),
            subtitle: line.isEmpty ? null : line,
          ),
          if (offer == null)
            ProviderEndedCard(quote: quote, state: state, booking: booking)
          else
            JourneyBox(
              key: const Key('provider-request-offer-card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          offer.title?.trim().isNotEmpty == true
                              ? offer.title!.trim()
                              : 'عرضك',
                          style: JourneyType.of(
                            JourneyType.lead,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ProviderCaseTag(state: state),
                    ],
                  ),
                  // p19 «550,000 ر.ي · نسخة 1» (B-06).
                  Text(
                    '${providerMoneyLabel(offer.amount, offer.currency)}'
                    ' · نسخة ${offer.versionNo}',
                    style: JourneyType.of(
                      JourneyType.bodySmall,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  if (offer.message?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      offer.message!.trim(),
                      style: JourneyType.of(JourneyType.body, height: 1.5),
                    ),
                  ],
                  if (offer.validUntil case final until? when canChange) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 18,
                          color: AarastV3Color.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validityLine(until.toLocal(), renew),
                            style: JourneyType.of(JourneyType.bodySmall),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (canChange) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: JourneyButton(
                    key: Key('provider-offer-open-${quote.id}'),
                    label: renew ? 'جدّد العرض' : 'عدّل العرض',
                    icon: renew ? LucideIcons.refreshCw : LucideIcons.pencil,
                    background: AarastV3Color.primarySoft,
                    foreground: AarastV3Color.primary,
                    expand: true,
                    onPressed: () =>
                        context.push(AppRouter.providerRequestOffer(quote.id)),
                  ),
                ),
                const SizedBox(width: 10),
                // B-03: an offer the customer has not decided on.
                Expanded(
                  child: JourneyButton(
                    key: Key('provider-offer-withdraw-${quote.id}'),
                    label: 'اسحب العرض',
                    background: AarastV3Color.paper,
                    foreground: AarastV3Color.danger,
                    expand: true,
                    onPressed: () => showProviderWithdrawSheet(
                      context,
                      quote: quote,
                      offerId: (quote.pendingOffer ?? quote.expiredOffer)!.id,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            JourneyNote(
              text:
                  'التعديل يوصله نسخة ${offer!.versionNo + 1} فيها «ايش تغيّر». '
                  'والسحب يقفل العرض ويوصله سطر هادي.',
            ),
          ],
          if (booking != null && state == ProviderCaseState.bookingAsked) ...[
            const SizedBox(height: 12),
            JourneyButton(
              key: Key('provider-booking-open-${booking.id}'),
              label: 'أكّد الحجز',
              icon: LucideIcons.calendarCheck,
              expand: true,
              large: true,
              onPressed: () => showProviderConfirmSheet(
                context,
                quote: quote,
                booking: booking,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: JourneyTextAction(
              key: const Key('provider-request-chat'),
              label: 'المحادثة',
              icon: LucideIcons.messageCircle,
              color: AarastV3Color.primary,
              onPressed: () =>
                  context.push(AppRouter.quoteConversation(quote.id)),
            ),
          ),
        ],
      ),
    );
  }

  /// «صالح لين 28 أكتوبر · باقي 8 أيام»: the end date is the server's.
  static String _validityLine(DateTime until, bool expired) {
    final day = formatArabicDayMonth(until);
    if (expired) return 'انتهى في $day';
    return 'صالح لين $day · ${providerDaysLeftLabel(until)}';
  }
}
