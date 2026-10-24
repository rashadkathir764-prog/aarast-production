import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/hijri_date.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, ProviderPackage, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';

/// Where a request stands for the provider, read on the phone from the
/// request, its offer and its booking (classification p15). The server has
/// no request expiry (F8), so nothing here counts time left on a request.
enum ProviderCaseState {
  /// SENT or VIEWED: waiting for his offer or his apology.
  fresh,

  /// The customer accepted and asked to book the day: confirm or decline.
  bookingAsked,

  /// RESPONDED with an offer that is still open.
  replied,

  /// ACCEPTED, and the customer has not asked to book yet.
  waitingBooking,

  /// The booking is confirmed.
  booked,

  /// The booked day has passed (`COMPLETED` is derived from the date).
  done,

  /// RESPONDED and the offer's end date passed (D35 renews it).
  offerExpired,

  /// The customer rejected the offer (no reason is stored, F7).
  notChosen,

  /// The provider declined the request.
  declined,

  /// The customer cancelled the request.
  cancelled,

  /// The provider declined the booking.
  bookingDeclined,

  /// The booking was cancelled by either side.
  bookingCancelled,
}

/// The four lists of p15.
enum ProviderRequestTab {
  fresh('جديد'),
  replied('ردّيت'),
  booked('محجوز'),
  ended('انتهى');

  const ProviderRequestTab(this.label);

  final String label;
}

extension ProviderCaseStateTab on ProviderCaseState {
  ProviderRequestTab get tab => switch (this) {
    ProviderCaseState.fresh ||
    ProviderCaseState.bookingAsked => ProviderRequestTab.fresh,
    ProviderCaseState.replied ||
    ProviderCaseState.waitingBooking => ProviderRequestTab.replied,
    ProviderCaseState.booked ||
    ProviderCaseState.done => ProviderRequestTab.booked,
    _ => ProviderRequestTab.ended,
  };

  /// The status word (prototype `st`), one colour each.
  (String, Color, Color) get tag => switch (this) {
    ProviderCaseState.fresh => (
      'جديد',
      AarastV3Color.danger,
      AarastV3Color.dangerSoft,
    ),
    ProviderCaseState.bookingAsked || ProviderCaseState.waitingBooking => (
      'قبلوا عرضك',
      AarastV3Color.brandAccentStrong,
      AarastV3Color.brandAccentSoft,
    ),
    ProviderCaseState.replied => (
      'ردّيت',
      AarastV3Color.cobalt,
      AarastV3Color.cobaltSoft,
    ),
    ProviderCaseState.booked => (
      'محجوز',
      AarastV3Color.mint,
      AarastV3Color.mintSoft,
    ),
    ProviderCaseState.done => (
      'تم',
      AarastV3Color.mint,
      AarastV3Color.mintSoft,
    ),
    ProviderCaseState.declined || ProviderCaseState.bookingDeclined => (
      'اعتذرت',
      AarastV3Color.textMuted,
      AarastV3Color.line,
    ),
    ProviderCaseState.cancelled || ProviderCaseState.bookingCancelled => (
      'ملغي',
      AarastV3Color.textMuted,
      AarastV3Color.line,
    ),
    _ => ('انتهى', AarastV3Color.textMuted, AarastV3Color.line),
  };
}

/// The request's booking: the one it carries (every status, F5), else the
/// open one in the bookings list.
MarketplaceBooking? providerBookingOf(
  QuoteRequest quote,
  ProviderDashboardProvider dashboard,
) => quote.booking ?? dashboard.bookingForQuote(quote.id);

ProviderCaseState providerCaseOf(
  QuoteRequest quote,
  MarketplaceBooking? booking,
) {
  if (booking != null) {
    if (booking.lifecycleStatus == 'COMPLETED') return ProviderCaseState.done;
    switch (booking.status.toUpperCase()) {
      case 'REQUESTED':
        return ProviderCaseState.bookingAsked;
      case 'CONFIRMED':
        return ProviderCaseState.booked;
      case 'DECLINED':
        return ProviderCaseState.bookingDeclined;
      case 'CANCELLED':
        return ProviderCaseState.bookingCancelled;
    }
  }
  return switch (quote.status.toUpperCase()) {
    'SENT' || 'VIEWED' => ProviderCaseState.fresh,
    'RESPONDED' =>
      quote.pendingOffer == null && quote.expiredOffer != null
          ? ProviderCaseState.offerExpired
          : ProviderCaseState.replied,
    'ACCEPTED' => ProviderCaseState.waitingBooking,
    // The provider can decline only before an offer; the customer rejects
    // an offer he received.
    'REJECTED' =>
      quote.offers.isEmpty
          ? ProviderCaseState.declined
          : ProviderCaseState.notChosen,
    _ => ProviderCaseState.cancelled,
  };
}

/// The customer's name as the request carries it (D35), never his phone.
String providerCustomerName(QuoteRequest quote) {
  for (final name in [quote.contactName, quote.userName]) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return 'العميل';
}

/// «محمد» from «محمد الحمدي».
String providerFirstName(String name) =>
    name.trim().split(RegExp(r'\s+')).first;

/// «550,000»; null when the text is not an amount.
String? providerGroupedAmount(String? raw) {
  final normalized = raw?.trim().replaceAll(',', '') ?? '';
  final value = num.tryParse(normalized);
  if (value == null) return null;
  final parts = normalized.split('.');
  final whole = parts.first.replaceFirst('-', '');
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  final fraction = parts.length > 1
      ? parts[1].replaceAll(RegExp('0+\$'), '')
      : '';
  if (fraction.isNotEmpty) buffer.write('.$fraction');
  return buffer.toString();
}

/// «550,000 ر.ي».
String providerMoneyLabel(String? amount, String? currency) {
  final grouped = providerGroupedAmount(amount) ?? amount?.trim() ?? '';
  return '$grouped ${currencyLabelAr(currency)}'.trim();
}

/// The currency an offer on [quote] must use: the plan's (the server
/// refuses another), else the offer's own, else the default.
String providerOfferCurrency(QuoteRequest quote) {
  final offer = quote.pendingOffer ?? quote.expiredOffer;
  return (quote.weddingPlanCurrency?.trim().isNotEmpty == true
          ? quote.weddingPlanCurrency!
          : offer?.currency?.trim().isNotEmpty == true
          ? offer!.currency!
          : defaultCurrencyCode)
      .trim()
      .toUpperCase();
}

/// The packages an offer on [quote] can start from: active, priced, in the
/// currency the offer must use.
List<ProviderPackage> providerOfferPackages(
  List<ProviderPackage> packages,
  QuoteRequest quote,
) {
  final currency = providerOfferCurrency(quote);
  return [
    for (final package in packages)
      if (package.isActive &&
          (num.tryParse(package.price?.trim() ?? '') ?? 0) > 0 &&
          (package.currency?.trim().isNotEmpty == true
                  ? package.currency!.trim().toUpperCase()
                  : defaultCurrencyCode) ==
              currency)
        package,
  ];
}

/// «الخميس 21 يناير · 13 شعبان»; the Hijri part only while the account
/// shows it.
String providerEventDayLabel(DateTime day, {required bool showHijri}) {
  final gregorian = formatArabicWeekdayDayMonth(day);
  final hijri = showHijri ? HijriDate.fromGregorian(day) : null;
  return hijri == null ? gregorian : '$gregorian · ${hijri.dayAndMonth}';
}

/// «الزفة · الخميس 21 يناير» without the occasion, which the server does
/// not hold: the day, then what he asked for.
String providerRequestLine(QuoteRequest quote) => [
  if (quote.eventDate case final day?) formatArabicWeekdayDayMonth(day),
  if (quote.service?.title.trim().isNotEmpty == true)
    quote.service!.title.trim(),
].join(' · ');

/// A status word on its soft fill.
class ProviderCaseTag extends StatelessWidget {
  const ProviderCaseTag({required this.state, super.key});

  final ProviderCaseState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = state.tag;
    return JourneyTag(label: label, color: color, soft: soft);
  }
}

/// What the day of the request holds in the provider's own calendar (p16),
/// at day level: a confirmed booking, a day he closed, or free (F9).
class ProviderDayStatus extends StatelessWidget {
  const ProviderDayStatus({
    required this.day,
    required this.dashboard,
    required this.quoteId,
    super.key,
  });

  final DateTime day;
  final ProviderDashboardProvider dashboard;
  final String quoteId;

  @override
  Widget build(BuildContext context) {
    bool sameDay(DateTime other) =>
        other.year == day.year &&
        other.month == day.month &&
        other.day == day.day;
    final booked = dashboard.bookings.any(
      (booking) =>
          booking.isConfirmed &&
          booking.quoteRequestId != quoteId &&
          sameDay(booking.eventDate),
    );
    final closed = dashboard.blockedDates.any(sameDay);
    final weekday = formatArabicWeekday(day);
    final (text, icon, color, soft) = booked
        ? (
            'يوم $weekday عندك حجز مؤكد',
            LucideIcons.calendarX,
            AarastV3Color.danger,
            AarastV3Color.dangerSoft,
          )
        : closed
        ? (
            'يوم $weekday قفلته في تقويمك',
            LucideIcons.calendarX,
            AarastV3Color.danger,
            AarastV3Color.dangerSoft,
          )
        : (
            'يوم $weekday فاضي عندك',
            LucideIcons.calendarCheck,
            AarastV3Color.mint,
            AarastV3Color.mintSoft,
          );
    return JourneyBox(
      key: const Key('provider-request-day-status'),
      color: soft,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.bodySmall,
                weight: JourneyType.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact of a request (prototype `kv`): a muted label, a bold value.
class ProviderFactLine extends StatelessWidget {
  const ProviderFactLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.detail,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
        ],
      ),
    );
  }
}
