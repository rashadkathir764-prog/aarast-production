import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/utils/plan_day.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventsProvider;
import '../data/plan_bookings_lookup.dart';
import '../data/wedding_moment_ledger.dart';

/// y06 «دخلت أسبوع عرسك» and y07 «اليوم عرسك يا محمد», each once per
/// phone from the home (D65): the week's events and the providers who
/// confirmed, then the day's programme. Every fact is the plan's; what has
/// no source (the cash for the nights, «وكل شي مرتب») is left out.
class WeddingMomentScreen extends StatefulWidget {
  const WeddingMomentScreen({
    required this.weddingPlanId,
    required this.moment,
    this.loadBookings,
    super.key,
  });

  final String weddingPlanId;
  final WeddingMoment moment;

  /// The plan's bookings for y06's providers row; the server's by default.
  final Future<List<PlanBookingDay>> Function(String weddingPlanId)?
  loadBookings;

  @override
  State<WeddingMomentScreen> createState() => _WeddingMomentScreenState();
}

class _WeddingMomentScreenState extends State<WeddingMomentScreen> {
  List<PlanBookingDay>? _bookings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final events = context.read<PlanEventsProvider?>();
      if (events != null && events.viewOf(widget.weddingPlanId) == null) {
        events.load(widget.weddingPlanId);
      }
      if (widget.moment == WeddingMoment.week) _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    try {
      final load =
          widget.loadBookings ??
          PlanBookingsLookup(
            context.read<ApiClient>(),
            offline: context.read<OfflineSyncService?>(),
          ).list;
      final bookings = await load(widget.weddingPlanId);
      if (mounted) setState(() => _bookings = bookings);
    } on ApiException {
      // The providers row waits for a reading; the moment shows without it.
      if (mounted) setState(() => _bookings = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = context.watch<PlanEventsProvider?>()?.viewOf(
      widget.weddingPlanId,
    );
    // The wedding's own event carries the plan's date.
    final weddingDate = view?.items
        .where((event) => event.isMain)
        .firstOrNull
        ?.date;
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final profile = context.journeyProfile;
    final today = DateUtils.dateOnly(appNow());
    final week = widget.moment == WeddingMoment.week;

    String where(PlanEvent event, String first) =>
        [first, ?event.placeLabel].join(' · ');

    final rows = <(IconData, String, String)>[];
    if (weddingDate != null && view != null) {
      if (week) {
        for (final event in view.weekOf(weddingDate)) {
          rows.add((
            event.type.icon,
            event.name(profile),
            where(event, formatArabicWeekday(event.date!)),
          ));
        }
      } else {
        for (final event in view.dayOf(weddingDate)) {
          rows.add((
            event.type.icon,
            event.name(profile),
            where(event, event.timeLabel ?? 'اليوم'),
          ));
        }
      }
    }
    final bookings = _bookings;
    if (week && bookings != null && bookings.isNotEmpty) {
      final confirmed = bookings.where((booking) => booking.confirmed).length;
      rows.add((
        LucideIcons.store,
        'المزودين',
        '$confirmed من ${bookings.length} ${context.planWord('أكّدوا', 'أكّدن')}',
      ));
    }

    final name = (context.watch<AuthController?>()?.user?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final hijri = showHijri ? HijriDate.fromGregorian(today) : null;
    // D11: from today in Sana'a, as the server counts (RA-MO-20).
    // RA-MO-189: unknown until the plan's events are read. It was taken as
    // seven, so the page said «سبعة أيام على عرسك» to anyone whose events
    // had not arrived (no connection and no copy), whatever the day.
    final days = weddingDate == null ? null : daysUntilPlanDay(weddingDate);
    final color = week ? context.accent.night : AarastV3Color.saffron;

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: color,
      child: JourneyMoment(
        color: color,
        picture: const CustomPaint(
          painter: JourneyLightsPainter(strands: 11, lit: 11, apexY: 0.03),
        ),
        eyebrow: week
            ? formatArabicWeekdayDayMonth(today)
            : [
                formatArabicWeekdayDayMonth(today),
                ?hijri?.dayAndMonth,
              ].join(' · '),
        title: week
            ? 'دخلت أسبوع عرسك'
            : name.isEmpty
            ? 'اليوم عرسك'
            : 'اليوم عرسك يا $name',
        subtitle: week
            ? [
                if (days != null)
                  days == 7
                      ? 'سبعة أيام على عرسك.'
                      : '${days <= 0 ? 'اليوم' : arabicDays(days)} على عرسك.',
                'من اليوم الرئيسية تمشي معك ليلة ليلة.',
              ].join('\n')
            : 'بارك الله لكما، وبارك عليكما،\nوجمع بينكما في خير.',
        body: rows.isEmpty
            ? const SizedBox.shrink()
            : JourneyGlassRows(rows: rows),
        action: week
            // The reader is speaking, not being spoken to, so this one
            // wording serves both.
            ? 'وريني برنامج الأسبوع'
            : context.say('ابدأ يومك', 'ابدئي يومك'),
        onAction: () => context.popOrGo(
          AppRouter.weddingPlanDashboard(widget.weddingPlanId),
        ),
      ),
    );
  }
}
