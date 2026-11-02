part of 'aarast_dashboard_view.dart';

// The wedding week (b04, with y12's past nights) and the wedding day (b05),
// built from the plan's events (D65). Nothing here is guessed: the cash for
// the nights and a decor banner have no source and are left out.

/// The home's greeting in the week and on the day.
String _weddingWindowGreeting(
  BuildContext context, {
  required int days,
  required String name,
}) {
  if (days <= 0) {
    return context.planWord('مبروك يا عريس', 'مبروك يا عروسة');
  }
  final left = days == 1 ? 'بكرة عرسك' : 'باقي ${arabicDays(days)}';
  return name.isEmpty ? left : '$left يا $name';
}

/// b04/b05's hero: the wedding lights over the plan's night, a strand lit
/// for every night that has passed («كل ليلة تنوّر حبل · 5 من 7»), the
/// fireworks full on the day.
class _WeddingSkyHero extends StatelessWidget {
  const _WeddingSkyHero({
    required this.days,
    required this.date,
    required this.showHijri,
    required this.onTap,
  });

  final int days;
  final DateTime date;
  final bool showHijri;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = days <= 0;
    final lit = day ? 7 : (7 - days).clamp(0, 7);
    final hijri = showHijri ? HijriDate.fromGregorian(date) : null;
    final line = day
        ? [?hijri?.dayAndMonth, formatArabicWeekday(date)].join(' · ')
        : 'كل ليلة تنوّر حبل · $lit من 7';
    final count = day ? 'اليوم' : '$days';
    final title = day
        ? 'يوم عرسك'
        : (days == 1 ? 'يوم واحد على عرسك' : 'يوم على عرسك');
    final accent = context.accent;
    return Semantics(
      button: true,
      label: '$count $title، $line',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        key: ValueKey(
          day ? 'aarast-dashboard-day-hero' : 'aarast-dashboard-week-hero',
        ),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 330,
            child: Stack(
              fit: StackFit.expand,
              children: [
                JourneyWeddingSky(
                  strands: 7,
                  lit: lit,
                  fireAlpha: day ? 0.9 : 0.45,
                  bursts: day
                      ? [
                          (
                            const Offset(0.15, 0.14),
                            AarastV3Color.saffron,
                            46.0,
                          ),
                          (const Offset(0.85, 0.12), JourneyArt.warm, 52.0),
                          (const Offset(0.50, 0.34), accent.primaryMid, 34.0),
                          (
                            const Offset(0.88, 0.45),
                            AarastV3Color.saffron,
                            30.0,
                          ),
                        ]
                      : const [
                          (Offset(0.16, 0.16), AarastV3Color.saffron, 34.0),
                          (Offset(0.84, 0.13), JourneyArt.warm, 38.0),
                        ],
                  base: accent.primaryDark,
                ),
                PositionedDirectional(
                  start: 20,
                  end: 20,
                  bottom: 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // As on b01/b02: the tag sits on the count's row when the
                      // phone is wide enough, else above the moments.
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final wide = constraints.maxWidth / scale >= 300;
                      final tag = JourneyTag(
                        label: day ? 'يوم العرس' : 'أسبوع العرس',
                        color: AarastV3Color.ink,
                        soft: AarastV3Color.saffron,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // The count keeps its size; only a very narrow
                              // card scales it down.
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.45,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.bottomStart,
                                  child: Text(
                                    count,
                                    style: JourneyType.of(
                                      day ? 50 : JourneyType.homeCount,
                                      weight: JourneyType.bold,
                                      color: AarastV3Color.onPrimary,
                                      height: 0.95,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: JourneyType.of(
                                          JourneyType.title,
                                          weight: JourneyType.bold,
                                          color: AarastV3Color.onPrimary,
                                        ),
                                      ),
                                      Text(
                                        line,
                                        style: JourneyType.of(
                                          JourneyType.detail,
                                          color: JourneyArt.warm,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (wide) ...[const SizedBox(width: 8), tag],
                            ],
                          ),
                          if (!wide) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: tag,
                            ),
                          ],
                          const SizedBox(height: 14),
                          _StagePath(current: day ? 3 : 2),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// b04 «برنامج الأسبوع» (y12's nights): each event of the wedding week by its
/// day, «الليلة» on today's, the passed ones quiet with a tick.
class _WeekProgram extends StatelessWidget {
  const _WeekProgram({
    required this.events,
    required this.today,
    required this.onEdit,
  });

  final List<PlanEvent> events;
  final DateTime today;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    return Column(
      key: const ValueKey('aarast-dashboard-week-program'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          'برنامج الأسبوع',
          action: onEdit == null ? null : 'تعديل',
          onAction: onEdit,
          actionColor: context.accent.primary,
        ),
        if (events.isEmpty)
          _ProgramEmpty(onAdd: onEdit)
        else
          JourneyList(
            children: [
              for (final event in events)
                _WeekRow(
                  event: event,
                  profile: profile,
                  tonight: event.isOn(today),
                  passed: event.date!.isBefore(today),
                ),
            ],
          ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.event,
    required this.profile,
    required this.tonight,
    required this.passed,
  });

  final PlanEvent event;
  final JourneyProfile profile;
  final bool tonight;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final date = event.date!;
    final tileColor = tonight
        ? accent.primary
        : passed
        ? AarastV3Color.canvas
        : accent.primarySoft;
    final tileText = tonight
        ? AarastV3Color.onPrimary
        : passed
        ? AarastV3Color.textFaint
        : AarastV3Color.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  formatArabicWeekday(date),
                  style: JourneyType.of(
                    JourneyType.caption,
                    weight: JourneyType.bold,
                    color: tonight
                        ? AarastV3Color.onPrimary
                        : AarastV3Color.textMuted,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                    color: tileText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.name(profile),
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                          color: passed
                              ? AarastV3Color.textFaint
                              : AarastV3Color.ink,
                        ),
                      ),
                    ),
                    if (tonight) ...[
                      const SizedBox(width: 8),
                      JourneyTag(
                        label: event.isMain ? 'اليوم' : 'الليلة',
                        color: AarastV3Color.brandAccentStrong,
                        soft: AarastV3Color.brandAccentSoft,
                      ),
                    ],
                  ],
                ),
                Text(
                  [?event.placeLabel, ?event.timeLabel].join(' · '),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (passed)
            const Icon(
              LucideIcons.checkCircle,
              size: 22,
              color: AarastV3Color.mint,
            ),
        ],
      ),
    );
  }
}

/// No event in the week, or none on the day: the way to add them.
class _ProgramEmpty extends StatelessWidget {
  const _ProgramEmpty({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('aarast-dashboard-program-empty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ما فيه مناسبات مسجلة',
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          Text(
            onAdd == null
                ? 'لما تتسجل مناسبات العرس تطلع هنا.'
                : context.say(
                    'سجّل السمرة والمقيل والزفاف، وتطلع هنا بأيامها.',
                    'سجّلي مناسباتك، وتطلع هنا بأيامها.',
                  ),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 12),
            JourneyButton(
              label: context.say('سجّل مناسباتك', 'سجّلي مناسباتك'),
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

/// b04 «المزودين · أكّدوا 5 من 6»: the plan's bookings for the coming days,
/// confirmed by their provider or still asked (D65: the booking's own
/// confirmation; a second «reconfirm» has no source and is not drawn).
class _WeekProviders extends StatelessWidget {
  const _WeekProviders({required this.bookings, required this.onTap});

  final List<DashboardWeekBooking> bookings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final confirmed = bookings.where((booking) => booking.confirmed).length;
    final names = [
      for (final booking in bookings) booking.providerName,
    ].join('، ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('المزودين'),
        AarastPressable(
          key: const ValueKey('aarast-dashboard-week-providers'),
          onTap: onTap,
          semanticLabel:
              '${context.planWord('أكّدوا', 'أكّدن')} $confirmed من ${bookings.length}، $names',
          borderRadius: BorderRadius.circular(18),
          child: JourneyBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${context.planWord('أكّدوا', 'أكّدن')} $confirmed من ${bookings.length}',
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        names,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                JourneySegments(
                  total: bookings.length,
                  done: confirmed,
                  filled: context.accent.primary,
                  current: AarastV3Color.danger,
                  empty: AarastV3Color.line,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One booking the plan holds for the wedding week (b04's providers card).
class DashboardWeekBooking {
  const DashboardWeekBooking({
    required this.providerName,
    required this.confirmed,
  });

  final String providerName;
  final bool confirmed;
}

/// b05 «برنامج اليوم»: the day's events by their time; the one under way
/// reads «الآن», the ones before it are quiet.
class _DayProgram extends StatelessWidget {
  const _DayProgram({
    required this.events,
    required this.now,
    required this.onEdit,
  });

  final List<PlanEvent> events;
  final DateTime now;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    final moments = programMoments(events, now);
    final accent = context.accent;
    return Column(
      key: const ValueKey('aarast-dashboard-day-program'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          'برنامج اليوم',
          action: onEdit == null || events.isEmpty ? null : 'تعديل',
          onAction: onEdit,
          actionColor: accent.primary,
        ),
        if (events.isEmpty)
          _ProgramEmpty(onAdd: onEdit)
        else
          JourneyBox(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (var index = 0; index < events.length; index++)
                  _DayRow(
                    event: events[index],
                    profile: profile,
                    moment: moments[index],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.event,
    required this.profile,
    required this.moment,
  });

  final PlanEvent event;
  final JourneyProfile profile;
  final PlanEventMoment moment;

  @override
  Widget build(BuildContext context) {
    final now = moment == PlanEventMoment.now;
    final done = moment == PlanEventMoment.done;
    final accent = context.accent;
    final who = [?event.placeLabel, ?event.responsibleName, ?event.note];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              event.timeLabel ?? '—',
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: now
                    ? accent.primary
                    : done
                    ? AarastV3Color.textFaint
                    : AarastV3Color.ink,
              ),
            ),
          ),
          SizedBox.square(
            dimension: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: now
                    ? AarastV3Color.saffron
                    : done
                    ? AarastV3Color.line
                    : accent.primaryMid,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name(profile),
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: done ? AarastV3Color.textFaint : AarastV3Color.ink,
                  ),
                ),
                if (who.isNotEmpty)
                  Text(
                    who.join(' · '),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (now)
            const JourneyTag(
              label: 'الآن',
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
            ),
        ],
      ),
    );
  }
}
