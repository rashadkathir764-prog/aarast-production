import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/hijri_date.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, ProviderPackage, QuoteRequest;
import '../data/provider_offer_queue.dart'
    show ProviderDroppedOffer, ProviderOfferDropReason;
import '../providers/provider_dashboard_provider.dart';
import 'provider_join_parts.dart' show providerMomentLabel;

/// A fixed dimension of this layout, not a spacing step (D74).
const _requestLabelWidth = 92.0;

/// Where a request stands for the provider, read on the phone from the
/// request, its offer and its booking (classification p15). A new request
/// has seven days to be answered (B-04, `expiresAt`), then it ends.
enum ProviderCaseState {
  /// SENT or VIEWED: waiting for his offer or his apology (also after he
  /// withdrew his offer, B-03).
  fresh,

  /// EXPIRED: seven days passed without his answer (B-04), from the moment
  /// the deadline passes (`QuoteRequest.isPastAnswerDeadline`).
  unanswered,

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

  /// B-22: he recorded «ما صار». It read «محجوز», with reminders and a
  /// cancel the server always refuses (RA-MO-291).
  notHappened,

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
    ProviderCaseState.notHappened => (
      'ما صار',
      AarastV3Color.textMuted,
      AarastV3Color.line,
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
    if (booking.lifecycleStatus == 'NOT_HAPPENED') {
      return ProviderCaseState.notHappened;
    }
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
    'EXPIRED' => ProviderCaseState.unanswered,
    // The provider declines with no open offer (none sent, or his offer
    // withdrawn, B-03); the customer rejects an offer he received.
    'REJECTED' =>
      quote.rejectedByCustomer
          ? ProviderCaseState.notChosen
          : ProviderCaseState.declined,
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

/// «400,000 لين 600,000 ر.ي» from the budget the customer shared (B-08);
/// null when none came with the request.
String? providerBudgetLabel(QuoteRequest quote) {
  final min = providerGroupedAmount(quote.budgetMin);
  final max = providerGroupedAmount(quote.budgetMax);
  final currency = currencyLabelAr(quote.weddingPlanCurrency);
  if (min != null && max != null && min != max) {
    return '$min لين $max $currency';
  }
  final one = max ?? min;
  return one == null ? null : '$one $currency';
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

/// «باقي 8 أيام» to an offer's end day; «آخر يوم اليوم» on it.
String providerDaysLeftLabel(DateTime until, {DateTime? now}) {
  final clock = now ?? appNow();
  final days = DateTime(
    until.year,
    until.month,
    until.day,
  ).difference(DateTime(clock.year, clock.month, clock.day)).inDays;
  return switch (days) {
    <= 0 => 'آخر يوم اليوم',
    1 => 'باقي يوم',
    2 => 'باقي يومين',
    <= 10 => 'باقي $days أيام',
    _ => 'باقي $days يوم',
  };
}

/// «الزفة · الخميس 21 يناير» without the occasion, which the server does
/// not hold: the day, then what he asked for.
String providerRequestLine(QuoteRequest quote) => [
  if (quote.eventDate case final day?) formatArabicWeekdayDayMonth(day),
  if (quote.service?.title.trim().isNotEmpty == true)
    quote.service!.title.trim(),
].join(' · ');

/// p43's bar: no network, and what still works without it. Only a new
/// offer waits on the phone (B-34), so only it is promised.
class ProviderOfflineBar extends StatelessWidget {
  const ProviderOfflineBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider-offline-bar'),
      padding: AarastV3Density.chipInsets,
      decoration: BoxDecoration(
        color: AarastV3Color.ink,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.wifiOff,
            size: 17,
            color: AarastV3Color.onPrimary,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              'بدون نت. العرض اللي ترسله ينحفظ في جوالك ويوصل لما يرجع النت.',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One request's page (p16, p19, p22, p25): pulled down it reads his
/// requests again, and without the network it says that what shows is the
/// last copy (RA-MO-290: these pages showed what the phone held, with no
/// way to read again and no word that it was old). The bar goes under the
/// page's header, the first of [children].
class ProviderCaseList extends StatelessWidget {
  const ProviderCaseList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AarastV3Density.pageInsets,
        children: [
          ...children.take(1),
          if (dashboard.isOffline) ...[
            const ProviderOfflineBar(),
            const SizedBox(height: AarastV3Space.x3),
          ],
          ...children.skip(1),
        ],
      ),
    );
  }
}

/// «آخر تحديث قبل 12 دقيقة»: when his data was last read.
String providerUpdatedLabel(DateTime at, {DateTime? now}) {
  final clock = now ?? appNow();
  final minutes = clock.difference(at).inMinutes;
  if (minutes < 1) return 'آخر تحديث قبل لحظات';
  if (minutes < 60) {
    return 'آخر تحديث قبل ${arabicCount(minutes, one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة')}';
  }
  final hours = clock.difference(at).inHours;
  if (hours < 24 && clock.day == at.day) {
    return 'آخر تحديث قبل ${arabicCount(hours, one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة')}';
  }
  return 'آخر تحديث ${providerMomentLabel(at, now: clock)}';
}

/// Said when an offer waits on the phone for the network (p43).
const providerQueuedOfferToast =
    'بدون نت. عرضك محفوظ على جوالك، وينرسل أول ما يرجع النت.';

/// p43's line for an offer kept on the phone: «عرضك لعادل ينتظر النت».
class ProviderQueuedOfferBox extends StatelessWidget {
  const ProviderQueuedOfferBox({required this.name, super.key});

  /// The customer's first name.
  final String name;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 18,
                color: AarastV3Color.brandAccentStrong,
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: Text(
                  'عرضك ل$name ينتظر النت',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'محفوظ على جوالك، وينرسل أول ما يرجع النت',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Why an offer kept on the phone did not go, in his words: «ما أرسلنا
/// عرضك المحفوظ لعادل: انتهت مدة الرد قبل ما يرجع النت».
String providerDroppedOfferLine(ProviderDroppedOffer dropped, String name) {
  final why = switch (dropped.reason) {
    ProviderOfferDropReason.requestGone => 'الطلب ما عاد في قائمتك',
    ProviderOfferDropReason.alreadyAnswered => 'الطلب عليه عرض منك من قبل',
    ProviderOfferDropReason.expired => 'انتهت مدة الرد قبل ما يرجع النت',
    ProviderOfferDropReason.cancelled => 'ألغى الطلب',
    ProviderOfferDropReason.declined => 'اعتذرت عن الطلب',
    ProviderOfferDropReason.closed => 'الطلب ما عاد ينتظر ردك',
    ProviderOfferDropReason.refused =>
      dropped.serverMessage?.trim().isNotEmpty == true
          ? dropped.serverMessage!.trim()
          : 'ما قبله النظام',
  };
  return 'ما أرسلنا عرضك المحفوظ ل$name: $why';
}

/// p43's companion to the waiting offer (undrawn): the kept offers that did
/// not go when the network came back, each with its reason, until he closes
/// the note. A kept offer is never dropped without a word.
class ProviderDroppedOffersBox extends StatelessWidget {
  const ProviderDroppedOffersBox({
    required this.lines,
    required this.onDismiss,
    super.key,
  });

  final List<String> lines;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertCircle,
                size: 18,
                color: AarastV3Color.danger,
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: Text(
                  lines.length == 1
                      ? 'عرض محفوظ ما انرسل'
                      : 'عروض محفوظة ما انرسلت',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              JourneyTextAction(
                key: const Key('provider-dropped-offers-dismiss'),
                label: 'تمام',
                onPressed: onDismiss,
                color: AarastV3Color.primary,
              ),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: AarastV3Space.x1),
              child: Text(
                line,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AarastV3Space.x2),
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

/// The facts a request holds (prototype `_facts`, p16 and p22): the day
/// (with the Hijri day while shown), the place, the guests and what he
/// asked for. The occasion and the period have no field; an empty fact is
/// left out.
class ProviderRequestFacts extends StatelessWidget {
  const ProviderRequestFacts({
    required this.quote,
    required this.showHijri,
    this.day,
    super.key,
  });

  final QuoteRequest quote;
  final bool showHijri;

  /// The booked day, when it is the one to show; else the request's.
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final location = quote.location;
    final place =
        (location?.fullLabel ?? location?.mediumLabel ?? location?.shortLabel)
            ?.trim() ??
        '';
    final guests = quote.guestCount;
    final wants = quote.service?.title.trim() ?? '';
    final facts = [
      if (day ?? quote.eventDate case final day?)
        ('اليوم', providerEventDayLabel(day, showHijri: showHijri)),
      if (place.isNotEmpty) ('المكان', place),
      if (guests != null && guests > 0) ('الضيوف', '$guests تقريبًا'),
      if (wants.isNotEmpty) ('يشتي', wants),
      // B-08: only what the customer chose to share reaches the provider.
      if (quote.shareBudget)
        if (providerBudgetLabel(quote) case final budget?) ('ميزانيته', budget),
      if (quote.shareContact)
        if (quote.contactPhone?.trim() case final phone? when phone.isNotEmpty)
          ('رقمه', phone),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return JourneyBox(
      key: const Key('provider-request-facts'),
      child: Column(
        children: [
          for (final (label, value) in facts)
            ProviderFactLine(label: label, value: value),
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
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _requestLabelWidth,
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
