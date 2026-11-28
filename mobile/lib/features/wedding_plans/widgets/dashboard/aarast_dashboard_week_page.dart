part of 'aarast_dashboard_view.dart';

// D134 (Rashad, 2026-11-27): the home stays the approved home in every
// stage. The wedding week no longer takes it over: one slim card under
// «الخطوة الجاية» says the week's state from the day the date is set, and
// opens «أسبوع العرس», the page that holds the sky and the program the home
// used to turn into.

/// The home's «أسبوع العرس» card: the kit's list row on the plan's soft
/// colour, with a tag beside the title that says where the week stands.
class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.days,
    required this.weddingDate,
    required this.events,
    required this.today,
    required this.onTap,
  });

  /// Days from today to the wedding, in Sana'a (D11).
  final int days;
  final DateTime weddingDate;

  /// The plan's events; null until read, and the card says less.
  final PlanEventsView? events;

  /// Today in Sana'a (RA-MO-354).
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final profile = context.journeyProfile;
    final view = events;
    final week = view?.weekOf(weddingDate) ?? const <PlanEvent>[];
    String named(PlanEvent event) => [
      event.nameIn(profile, view!.items),
      ?event.placeLabel,
      ?event.timeLabel,
    ].join(' · ');
    PlanEvent? tonight;
    PlanEvent? coming;
    for (final event in week) {
      if (event.isOn(today)) tonight ??= event;
      if (!event.date!.isBefore(today)) coming ??= event;
    }

    String? tag;
    var warm = false;
    final String line;
    if (view == null) {
      // Not read yet: the door stays, and promises nothing it cannot name.
      tag = days > weddingWeekDays
          ? 'بعد ${arabicDays(days - weddingWeekDays)}'
          : null;
      line = 'برنامج الليالي والمناسبات';
    } else if (week.isEmpty) {
      tag = days > weddingWeekDays
          ? 'بعد ${arabicDays(days - weddingWeekDays)}'
          : null;
      line = view.canEdit
          ? context.say('سجّل مناسبات أسبوعك', 'سجّلي مناسبات أسبوعك')
          : 'ما فيه مناسبات مسجلة';
    } else if (days > weddingWeekDays) {
      tag = 'بعد ${arabicDays(days - weddingWeekDays)}';
      final first = week.first;
      final firstLine =
          '${first.nameIn(profile, view.items)}، '
          '${formatArabicWeekdayDayMonth(first.date!)}';
      // One event is named alone: «مناسبة واحدة · أولها الزفاف» counted one
      // thing and called it the first of them (the real app's own data).
      line = week.length == 1
          ? firstLine
          : '${arabicCount(week.length, one: 'مناسبة واحدة', two: 'مناسبتين', few: 'مناسبات', many: 'مناسبة')}'
                ' · أولها $firstLine';
    } else if (tonight != null) {
      // As the program's own row says it: the wedding itself is a day.
      tag = tonight.isMain || days <= 0 ? 'اليوم' : 'الليلة';
      warm = true;
      line = named(tonight);
    } else if (coming != null) {
      tag = formatArabicWeekday(coming.date!);
      line = named(coming);
    } else {
      line = 'خلصت مناسبات الأسبوع';
    }

    return JourneyBox(
      key: const ValueKey('aarast-dashboard-week-card'),
      color: accent.primarySoft,
      padding: EdgeInsets.zero,
      child: AarastPressable(
        onTap: onTap,
        semanticLabel: ['أسبوع العرس', ?tag, line].join('، '),
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: Padding(
          padding: AarastV3Density.chipInsets,
          child: Row(
            children: [
              JourneyIconTile(
                icon: LucideIcons.calendarHeart,
                color: accent.primary,
                soft: AarastV3Color.paper,
                size: AarastV3Size.mark,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The title is never cut: on a narrow phone or a large
                    // text the tag takes the line under it (320 at 1.3 cut
                    // it to «أسبوع الـ…» beside the tag).
                    Wrap(
                      spacing: AarastV3Space.x2,
                      runSpacing: AarastV3Space.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'أسبوع العرس',
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                        if (tag != null)
                          JourneyTag(
                            key: const ValueKey('aarast-dashboard-week-tag'),
                            label: tag,
                            color: warm
                                ? AarastV3Color.brandAccentStrong
                                : accent.primary,
                            soft: warm
                                ? AarastV3Color.brandAccentSoft
                                : AarastV3Color.paper,
                          ),
                      ],
                    ),
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              const Icon(
                LucideIcons.chevronLeft,
                size: AarastV3Icon.md,
                color: AarastV3Color.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «أسبوع العرس», the page the home's card opens (D134): the wedding sky,
/// what is due today (D112, Q-20), the week's program or the day's, and the
/// providers who confirmed. Built from the plan's events (D65); before the
/// week opens it shows the program that is coming.
class WeddingWeekView extends StatelessWidget {
  const WeddingWeekView({
    required this.weddingDate,
    required this.events,
    required this.onOpenPlan,
    required this.onOpenTasks,
    this.summary,
    this.weekBookings,
    this.onOpenEvents,
    this.onOpenProviders,
    this.onOpenPayment,
    this.amountsHidden = false,
    this.showHijri = true,
    this.now,
    super.key,
  });

  final DateTime weddingDate;
  final PlanEventsView events;

  /// The plan's summary when it is at hand, for what is due today; without
  /// it the page shows the program alone.
  final DashboardSummary? summary;

  /// The plan's bookings for the coming days, read in the week only.
  final List<DashboardWeekBooking>? weekBookings;

  final VoidCallback onOpenPlan;
  final VoidCallback onOpenTasks;

  /// «مناسبات عرسك», for whoever may edit the plan's events.
  final VoidCallback? onOpenEvents;
  final VoidCallback? onOpenProviders;
  final ValueChanged<DashboardNextPaymentSchedule>? onOpenPayment;
  final bool amountsHidden;
  final bool showHijri;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? appNow();
    final stage = resolveWeddingPlanStage(weddingDate, now: now);
    final days = stage.daysUntilWedding ?? 0;
    final married = stage.stage == WeddingPlanStage.wrapUp;
    final today = sanaaToday(now: clock);
    final plan = summary;
    // D112 (Q-20), RA-MO-326: in the week and on the day, the payment that
    // is late or falls before the wedding, and today's tasks.
    final dueSoon = stage.isWeddingWindow && plan != null && plan.canViewMoney
        ? plan.nextPaymentScheduleDue
        : null;
    final dueDays = dueSoon == null
        ? null
        : daysUntilPlanDay(dueSoon.dueDate, now: clock);
    final payDue = dueSoon != null && dueDays! <= days ? dueSoon : null;
    final tasksToday = stage.isWeddingWindow ? plan?.todayTasks ?? 0 : 0;
    final edit = events.canEdit ? onOpenEvents : null;
    final bookings = weekBookings;
    final openPayment = onOpenPayment;

    return Column(
      key: const ValueKey('wedding-week-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!married) ...[
          _WeddingSkyHero(
            days: days,
            date: weddingDate,
            showHijri: showHijri,
            onTap: onOpenPlan,
            moment: _homeMoment(stage.stage, startingOut: false),
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        if (payDue != null || tasksToday > 0) ...[
          _TodayDue(
            payment: payDue,
            paymentDays: dueDays,
            tasks: tasksToday,
            currency: plan!.currency,
            amountsHidden: amountsHidden,
            onOpenPayment: payDue == null || openPayment == null
                ? null
                : () => openPayment(payDue),
            onOpenTasks: onOpenTasks,
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        if (days <= 0 && !married)
          _DayProgram(
            events: events.dayOf(weddingDate),
            planEvents: events.items,
            now: clock,
            onEdit: edit,
          )
        else
          _WeekProgram(
            events: events.weekOf(weddingDate),
            planEvents: events.items,
            today: today,
            onEdit: edit,
          ),
        if (bookings != null && bookings.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x3),
          _WeekProviders(bookings: bookings, onTap: onOpenProviders ?? () {}),
        ],
      ],
    );
  }
}
