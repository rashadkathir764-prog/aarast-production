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
import '../widgets/provider_bookings.dart' show ProviderBookingPanel;
import '../widgets/provider_decline_sheet.dart';
import '../widgets/provider_join_parts.dart' show providerMomentLabel;
import '../widgets/provider_request_cards.dart' show ProviderEndedCard;
import '../widgets/provider_request_parts.dart';

/// One request as the provider sees it. A new one (SENT or VIEWED) is p16
/// «طلب جديد»: the facts the server holds, his own day, the message, and
/// the offer or the apology. Once he answered it is p19: his offer, its end
/// date, and its edit or renewal. Opening a new request tells the customer
/// it was seen, once (D35).
class ProviderRequestScreen extends StatefulWidget {
  const ProviderRequestScreen({required this.quoteId, super.key});

  final String quoteId;

  @override
  State<ProviderRequestScreen> createState() => _ProviderRequestScreenState();
}

class _ProviderRequestScreenState extends State<ProviderRequestScreen> {
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
    if (state == ProviderCaseState.fresh) {
      return _NewRequest(quote: quote, dashboard: dashboard);
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
    final location = quote.location;
    // No «لم يحدد الموقع» filler: an empty place is left out.
    final place =
        (location?.fullLabel ?? location?.mediumLabel ?? location?.shortLabel)
            ?.trim() ??
        '';
    final guests = quote.guestCount;
    final wants = quote.service?.title.trim() ?? '';
    final message = quote.message?.trim() ?? '';
    final facts = [
      if (quote.eventDate case final day?)
        ('اليوم', providerEventDayLabel(day, showHijri: showHijri)),
      if (place.isNotEmpty) ('المكان', place),
      if (guests != null && guests > 0) ('الضيوف', '$guests تقريبًا'),
      if (wants.isNotEmpty) ('يشتي', wants),
    ];
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
                      size: 44,
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
                if (facts.isNotEmpty) ...[
                  JourneyBox(
                    child: Column(
                      children: [
                        for (final (label, value) in facts)
                          ProviderFactLine(label: label, value: value),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
                if (quote.eventDate case final day?) ...[
                  ProviderDayStatus(
                    day: day,
                    dashboard: dashboard,
                    quoteId: quote.id,
                  ),
                  const SizedBox(height: 8),
                ],
                Center(
                  child: JourneyTextAction(
                    key: const Key('provider-request-ask'),
                    label: 'اسأله قبل ما ترد',
                    color: AarastV3Color.primary,
                    onPressed: () =>
                        context.push(AppRouter.quoteConversation(quote.id)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                  Text(
                    providerMoneyLabel(offer.amount, offer.currency),
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
            JourneyButton(
              key: Key('provider-offer-open-${quote.id}'),
              label: renew ? 'جدّد العرض' : 'عدّل العرض',
              icon: renew ? LucideIcons.refreshCw : LucideIcons.pencil,
              background: AarastV3Color.primarySoft,
              foreground: AarastV3Color.primary,
              expand: true,
              onPressed: () =>
                  context.push(AppRouter.providerRequestOffer(quote.id)),
            ),
            const SizedBox(height: 12),
            const JourneyNote(
              text:
                  'التعديل يغيّر العرض نفسه، وما يوصله تنبيه. لو غيّرت شيء، قله في المحادثة.',
            ),
          ],
          if (booking != null) ...[
            const SizedBox(height: 12),
            ProviderBookingPanel(booking: booking),
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
    final now = DateTime.now();
    final days = DateTime(
      until.year,
      until.month,
      until.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final left = switch (days) {
      <= 0 => 'آخر يوم اليوم',
      1 => 'باقي يوم',
      2 => 'باقي يومين',
      <= 10 => 'باقي $days أيام',
      _ => 'باقي $days يوم',
    };
    return 'صالح لين $day · $left';
  }
}
