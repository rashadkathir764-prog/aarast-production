import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_booking_aftercare.dart';
import '../widgets/provider_booking_sheets.dart';
import '../widgets/provider_calendar_parts.dart';
import '../widgets/provider_join_parts.dart' show providerMomentLabel;
import '../widgets/provider_request_parts.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _bookingLabelWidth = 72.0;

/// p22 «حجز محمد الحمدي»: a confirmed booking (or one whose day passed).
/// The facts the request holds, the agreement (the accepted offer's title,
/// amount and line, without «نسخة»: offers have no versions, B-07), the
/// reminders the server sends (7 days and 1 day before, F9), the chat and
/// the cancel. «وصلك» and «الباقي» are the customer's own record on the
/// agreement (B-18, D41: no deposit system). The drawn team row has no
/// field (D-2); a new day asked, «تم» and the delivery (B-22 to B-24) are
/// [ProviderBookingAftercare].
class ProviderBookingScreen extends StatelessWidget {
  const ProviderBookingScreen({
    required this.quote,
    required this.booking,
    super.key,
  });

  final QuoteRequest quote;
  final MarketplaceBooking booking;

  @override
  Widget build(BuildContext context) {
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final name = providerCustomerName(quote);
    final first = providerFirstName(name);
    // B-22: a booking he recorded «ما صار» is over too: no reminders, and
    // no cancel, which the server refuses once the outcome is decided.
    final notHappened = booking.lifecycleStatus == 'NOT_HAPPENED';
    final done = booking.lifecycleStatus == 'COMPLETED' || notHappened;
    // The offer the booking follows: its own id, else the accepted one.
    final offer =
        quote.offers
            .where((offer) => offer.id == booking.quoteOfferId)
            .firstOrNull ??
        quote.acceptedOffer;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ProviderCaseList(
        children: [
          JourneySubHeader(
            title: 'حجز $name',
            trailing: ProviderCaseTag(
              state: notHappened
                  ? ProviderCaseState.notHappened
                  : done
                  ? ProviderCaseState.done
                  : ProviderCaseState.booked,
            ),
          ),
          ProviderRequestFacts(
            quote: quote,
            day: booking.eventDate,
            showHijri: showHijri,
          ),
          if (offer != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyBox(
              key: const Key('provider-booking-agreement'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الاتفاق',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  Text(
                    [
                      if (offer.title?.trim().isNotEmpty == true)
                        offer.title!.trim(),
                      providerMoneyLabel(offer.amount, offer.currency),
                    ].join(' · '),
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (offer.message?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      offer.message!.trim(),
                      style: JourneyType.of(JourneyType.body, height: 1.5),
                    ),
                  ],
                  // B-18: what the customer recorded on this agreement in
                  // his money, read only (no payment system, D41).
                  if ((booking.money ?? quote.booking?.money)
                      case final money?) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    _MoneyRow(
                      key: const Key('provider-booking-paid'),
                      label: 'وصلك',
                      value: [
                        providerMoneyLabel(money.paid, money.currency),
                        if (money.lastPaidAt case final at?)
                          'آخرها ${formatArabicDayMonth(at.toLocal())}',
                      ].join(' · '),
                      color: AarastV3Color.mint,
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    _MoneyRow(
                      key: const Key('provider-booking-left'),
                      label: 'الباقي',
                      value: providerMoneyLabel(money.left, money.currency),
                    ),
                  ],
                ],
              ),
            ),
          ],
          // G25: the new day asked, «تم» or «ما صار», and the delivery.
          ProviderBookingAftercare(booking: booking, customerFirstName: first),
          if (!done) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyBox(
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.bell,
                    color: AarastV3Color.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      'نذكّرك أنت و$first قبل بأسبوع وبيوم',
                      style: JourneyType.of(JourneyType.bodySmall),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AarastV3Space.x3),
          Row(
            children: [
              Expanded(
                child: JourneyButton(
                  key: const Key('provider-booking-chat'),
                  label: 'المحادثة',
                  icon: LucideIcons.messageCircle,
                  background: AarastV3Color.primarySoft,
                  foreground: AarastV3Color.primary,
                  expand: true,
                  onPressed: () =>
                      context.push(AppRouter.quoteConversation(quote.id)),
                ),
              ),
              // A day that passed cannot be cancelled on the server.
              if (!done) ...[
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: JourneyButton(
                    key: Key('provider-booking-cancel-${booking.id}'),
                    label: 'إلغاء الحجز',
                    background: AarastV3Color.paper,
                    foreground: AarastV3Color.danger,
                    expand: true,
                    onPressed: () => _cancel(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final cancelled = await showProviderCancelSheet(
      context,
      quote: quote,
      booking: booking,
    );
    if (!cancelled || !context.mounted) return;
    AarastToast.showSuccess(context, 'انلغى الحجز، ووصله خبر.');
  }
}

/// p22's «وصلك» / «الباقي» rows: a muted label and its value.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color = AarastV3Color.ink,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: _bookingLabelWidth,
        child: Text(
          label,
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: color,
          ),
        ),
      ),
    ],
  );
}

/// p25 «حجز فهد ملغي»: a booking that ended before its day, cancelled by
/// either side or declined by him. Who, when and the reason (the one note
/// the server keeps, F9), and that the day is free again when it is. The
/// drawn deposit section waits for decision D-1 (B-18); «رجع فريق 2 فاضي»
/// is said at day level.
class ProviderBookingEndedScreen extends StatelessWidget {
  const ProviderBookingEndedScreen({
    required this.quote,
    required this.booking,
    super.key,
  });

  final QuoteRequest quote;
  final MarketplaceBooking booking;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final name = providerCustomerName(quote);
    final first = providerFirstName(name);
    final declined = booking.status.toUpperCase() == 'DECLINED';
    final byHim = declined || booking.cancelledBy == 'PROVIDER';
    final headline = declined
        ? 'اعتذرت عن الحجز'
        : byHim
        ? 'لغيت الحجز'
        : '$first لغى الحجز';
    final at = declined ? booking.declinedAt : booking.cancelledAt;
    final service = quote.service?.title.trim() ?? '';
    final line = [
      if (service.isNotEmpty) service,
      formatArabicWeekdayDayMonth(booking.eventDate),
      if (at != null) providerMomentLabel(at),
    ].join(' · ');
    final reason = booking.note?.trim() ?? '';
    final day = booking.eventDate;
    final today = providerToday();
    final info = providerDayOf(day, dashboard);
    // Said only while true: a day ahead that nothing holds now.
    final freed =
        !day.isBefore(today) &&
        info.confirmed.isEmpty &&
        !info.closed &&
        info.asked.isEmpty;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ProviderCaseList(
        children: [
          JourneySubHeader(
            title: 'حجز $name',
            trailing: ProviderCaseTag(
              state: declined
                  ? ProviderCaseState.bookingDeclined
                  : ProviderCaseState.bookingCancelled,
            ),
          ),
          JourneyBox(
            key: const Key('provider-booking-ended'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  line,
                  style: JourneyType.of(
                    JourneyType.detail,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    'السبب: «$reason»',
                    style: JourneyType.of(JourneyType.body),
                  ),
                ],
              ],
            ),
          ),
          if (freed) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyBox(
              key: const Key('provider-booking-day-freed'),
              color: AarastV3Color.mintSoft,
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.calendarPlus,
                    color: AarastV3Color.mint,
                    size: 20,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      'رجع اليوم فاضي في تقويمك',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                        color: AarastV3Color.mint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
