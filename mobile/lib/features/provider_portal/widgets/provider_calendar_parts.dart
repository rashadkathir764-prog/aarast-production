import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _calendarDayHeight = 55.0;

/// What one day holds in the provider's calendar (p28), at day level: he
/// takes his daily number of weddings (B-20, one by default) and closes
/// whole days (F11); no team and no period.
enum ProviderDayState {
  /// Nothing on it.
  free,

  /// Confirmed bookings, with room for more (p28 «باقي N»).
  room,

  /// As many confirmed bookings as he takes in a day.
  booked,

  /// A booking request waits for his confirmation (REQUESTED).
  waiting,

  /// He closed the day.
  closed,
}

/// A day with what it holds.
class ProviderDay {
  const ProviderDay({
    required this.day,
    required this.confirmed,
    required this.asked,
    required this.closed,
    this.capacity = 1,
  });

  final DateTime day;
  final List<MarketplaceBooking> confirmed;
  final List<MarketplaceBooking> asked;
  final bool closed;

  /// B-20: the weddings he takes on one day.
  final int capacity;

  /// Places left for another confirmation (never below zero: a number he
  /// lowered under the day's bookings keeps them).
  int get left =>
      capacity - confirmed.length < 0 ? 0 : capacity - confirmed.length;

  /// A full day first, then a request to answer, then a day with room, then
  /// a closed day: a closed day with a request still shows the request,
  /// which waits for his answer either way.
  ProviderDayState get state => confirmed.isNotEmpty && left == 0
      ? ProviderDayState.booked
      : asked.isNotEmpty
      ? ProviderDayState.waiting
      : confirmed.isNotEmpty
      ? ProviderDayState.room
      : closed
      ? ProviderDayState.closed
      : ProviderDayState.free;
}

bool providerSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Today on the phone, as a day.
DateTime providerToday([DateTime? now]) {
  final clock = now ?? appNow();
  return DateTime(clock.year, clock.month, clock.day);
}

/// The open bookings he holds: the bookings list (requests and upcoming
/// confirmed days, F10) and any open one a request carries (F5).
List<MarketplaceBooking> providerOpenBookings(
  ProviderDashboardProvider dashboard,
) {
  final seen = <String>{};
  return [
    for (final booking in [
      ...dashboard.bookings,
      for (final quote in dashboard.quoteRequests) ?quote.booking,
    ])
      if (booking.isOpen && seen.add(booking.id)) booking,
  ];
}

ProviderDay providerDayOf(DateTime day, ProviderDashboardProvider dashboard) {
  final open = providerOpenBookings(dashboard);
  return ProviderDay(
    day: day,
    confirmed: [
      for (final booking in open)
        if (booking.isConfirmed && providerSameDay(booking.eventDate, day))
          booking,
    ],
    asked: [
      for (final booking in open)
        if (booking.isRequested && providerSameDay(booking.eventDate, day))
          booking,
    ],
    closed: dashboard.blockedDates.any(
      (closed) => providerSameDay(closed, day),
    ),
    capacity: dashboard.profile?.dailyBookingCapacity ?? 1,
  );
}

/// The request a booking follows, when the list holds it.
QuoteRequest? providerQuoteOfBooking(
  ProviderDashboardProvider dashboard,
  MarketplaceBooking booking,
) {
  for (final quote in dashboard.quoteRequests) {
    if (quote.id == booking.quoteRequestId) return quote;
  }
  return null;
}

/// «يناير 2027».
String providerMonthLabel(DateTime month) =>
    '${arabicMonthName(month.month)} ${month.year}';

/// «رجب وشعبان 1448»: the Hijri months the Gregorian month crosses,
/// computed on the phone; null when the table does not cover it.
String? providerHijriMonthsLabel(DateTime month) {
  final first = HijriDate.fromGregorian(DateTime(month.year, month.month));
  final last = HijriDate.fromGregorian(
    DateTime(month.year, month.month + 1, 0),
  );
  if (first == null || last == null) return null;
  if (first.month == last.month && first.year == last.year) {
    return '${first.monthName} ${first.year}';
  }
  if (first.year == last.year) {
    return '${first.monthName} و${last.monthName} ${last.year}';
  }
  return '${first.monthName} ${first.year} و${last.monthName} ${last.year}';
}

/// The colours of a day's state (prototype p28: coral full, saffron
/// waiting, grey closed, white free).
(Color, Color) providerDayColors(ProviderDayState state) => switch (state) {
  ProviderDayState.booked => (AarastV3Color.danger, AarastV3Color.dangerSoft),
  ProviderDayState.room => (AarastV3Color.mint, AarastV3Color.mintSoft),
  ProviderDayState.waiting => (
    AarastV3Color.brandAccentStrong,
    AarastV3Color.brandAccentSoft,
  ),
  ProviderDayState.closed => (AarastV3Color.textFaint, AarastV3Color.line),
  ProviderDayState.free => (AarastV3Color.ink, AarastV3Color.paper),
};

/// The word under a day's number; [left] is the room a day has (B-20).
String? providerDayWord(ProviderDayState state, {int left = 0}) =>
    switch (state) {
      ProviderDayState.booked => 'محجوز',
      ProviderDayState.room => 'باقي $left',
      ProviderDayState.waiting => 'ينتظرك',
      ProviderDayState.closed => 'مقفول',
      ProviderDayState.free => null,
    };

/// A month of days, Saturday first (prototype p28): 50-point rounded cells
/// on the canvas, each with its number and, when it holds something, its
/// word in the state's colour. Today has a 2-point teal outline. Past days
/// are faint and do not open. In [selected] the days picked to close are
/// teal.
class ProviderMonthGrid extends StatelessWidget {
  const ProviderMonthGrid({
    required this.month,
    required this.dayOf,
    required this.onDay,
    this.selected = const {},
    this.today,
    super.key,
  });

  /// Any day in the month shown.
  final DateTime month;
  final ProviderDay Function(DateTime day) dayOf;
  final ValueChanged<DateTime> onDay;
  final Set<DateTime> selected;
  final DateTime? today;

  static const _weekdays = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    // Saturday is the first column: Saturday 0 … Friday 6.
    final offset = (first.weekday + 1) % 7;
    final rows = ((offset + count) / 7).ceil();
    final now = today ?? providerToday();
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: ExcludeSemantics(
                  child: Center(
                    child: Text(
                      weekday,
                      style: JourneyType.of(
                        JourneyType.label,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x1),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: () {
                    final date = row * 7 + column - offset + 1;
                    if (date < 1 || date > count) {
                      return const SizedBox(height: _calendarDayHeight);
                    }
                    final day = DateTime(month.year, month.month, date);
                    return _DayCell(
                      day: dayOf(day),
                      isToday: providerSameDay(day, now),
                      past: day.isBefore(now),
                      selected: selected.any(
                        (picked) => providerSameDay(picked, day),
                      ),
                      onTap: () => onDay(day),
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.past,
    required this.selected,
    required this.onTap,
  });

  final ProviderDay day;
  final bool isToday;
  final bool past;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = day.state;
    var (fg, bg) = providerDayColors(state);
    var word = providerDayWord(state, left: day.left);
    if (selected) {
      (fg, bg) = (AarastV3Color.onPrimary, AarastV3Color.primary);
      word = 'تقفله';
    } else if (past) {
      fg = AarastV3Color.textFaint;
    }
    final number = day.day.day;
    final label = [
      formatArabicWeekdayDayMonth(day.day),
      ?word,
      if (isToday) 'اليوم',
    ].join('، ');
    final cell = Container(
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        border: isToday
            ? Border.all(color: AarastV3Color.primary, width: 2)
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number',
              style: JourneyType.of(
                JourneyType.bodySmall,
                weight: JourneyType.bold,
                color: fg,
              ).copyWith(fontFamily: AarastV3Type.displayFamily),
            ),
            if (word != null)
              Text(
                word,
                style: JourneyType.of(
                  JourneyType.badge,
                  weight: state == ProviderDayState.closed && !selected
                      ? FontWeight.w400
                      : JourneyType.bold,
                  color: fg,
                ),
              ),
          ],
        ),
      ),
    );
    return Padding(
      key: Key('provider-calendar-day-$number'),
      padding: const EdgeInsets.all(AarastV3Space.x1),
      child: past
          ? Semantics(label: label, excludeSemantics: true, child: cell)
          : AarastPressable(
              onTap: onTap,
              semanticLabel: label,
              selected: selected,
              borderRadius: BorderRadius.circular(AarastV3Radius.control),
              child: cell,
            ),
    );
  }
}

/// The calendar's legend: a 10-point dot and its word per state shown.
class ProviderCalendarLegend extends StatelessWidget {
  const ProviderCalendarLegend({this.capacity = 1, super.key});

  /// B-20: a day with room only exists when he takes more than one.
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (capacity > 1) ('فيه مكان', ProviderDayState.room),
      (capacity > 1 ? 'مليان' : 'محجوز', ProviderDayState.booked),
      ('طلب ينتظرك', ProviderDayState.waiting),
      ('مقفول', ProviderDayState.closed),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (label, state) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: providerDayColors(state).$1,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AarastV3Space.x1),
              Text(
                label,
                style: JourneyType.of(
                  JourneyType.caption,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
