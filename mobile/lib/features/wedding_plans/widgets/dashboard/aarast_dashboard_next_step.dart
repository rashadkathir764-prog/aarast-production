part of 'aarast_dashboard_view.dart';

/// «الخطوة الجاية»: one honest next step. A due payment is named with its
/// amount and day, and opens recording that payment.
class _JourneyNextStep extends StatelessWidget {
  const _JourneyNextStep({
    required this.focus,
    required this.payment,
    required this.currency,
    required this.now,
    required this.amountsHidden,
    required this.onOpen,
  });

  final AarastDashboardFocus focus;
  final DashboardNextPaymentSchedule? payment;
  final String currency;
  final DateTime now;

  /// G17: «أخفِ المبالغ» reaches the next step's amount too.
  final bool amountsHidden;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final due = payment;
    final String eyebrow;
    final String title;
    final String reason;
    final String action;
    final IconData icon;
    // The days left to a due payment, drawn in the tile («5 أيام») so the
    // date is seen before it is read; null keeps the icon.
    int? daysLeft;
    String? dueAmount;
    if (due != null) {
      // D11, RA-MO-25: from today in Sana'a, as the server counts.
      final days = daysUntilPlanDay(due.dueDate, now: now);
      final when = days > 2
          ? null
          : days == 2
          ? 'بعد يومين'
          : days == 1
          ? 'بكرة'
          : days == 0
          ? 'اليوم'
          : 'متأخرة ${arabicCount(-days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
      if (days > 2) daysLeft = days;
      eyebrow = when == null ? 'الخطوة الجاية' : 'الخطوة الجاية · $when';
      title = due.title;
      final value = dashboardAmount(due.amount);
      dueAmount = amountsHidden || value == null
          ? null
          : '${formatDashboardAmount(value)} ${_currencyLabel(currency)}';
      reason = formatArabicWeekdayDayMonth(due.dueDate);
      action = context.say('سجّل الدفعة', 'سجّلي الدفعة');
      icon = LucideIcons.calendarClock;
    } else {
      eyebrow = 'الخطوة الجاية';
      title = focus.title;
      final value = dashboardAmount(focus.item?.amount);
      dueAmount = amountsHidden || value == null
          ? null
          : '${formatDashboardAmount(value)} ${_currencyLabel(currency)}';
      reason = focus.reason;
      action = focus.actionLabel;
      icon = focus.icon;
    }
    final urgent = focus.tone == AarastDashboardFocusTone.urgent;
    final accent = urgent || due != null
        ? AarastV3Color.brandAccentStrong
        : context.accent.primary;
    final soft = urgent || due != null
        ? AarastV3Color.brandAccentSoft
        : context.accent.primarySoft;
    final days = daysLeft;
    final tile = days == null
        ? JourneyIconTile(
            icon: icon,
            color: accent,
            soft: soft,
            size: AarastV3Space.x10,
            radius: AarastV3Radius.surface,
          )
        : _DaysTile(days: days, color: accent, soft: soft);
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          // The days are drawn in the tile, which a screen reader skips;
          // it hears them here, as the card said them before.
          semanticsLabel: days == null
              ? null
              : '$eyebrow · بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}',
          style: JourneyType.of(
            JourneyType.caption,
            weight: JourneyType.bold,
            color: accent,
          ),
        ),
        Text(
          title,
          style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
        ),
        Text.rich(
          TextSpan(
            children: [
              if (dueAmount != null) ...[
                TextSpan(
                  text: keepCurrencyOnLine(dueAmount),
                  style: JourneyType.of(
                    JourneyType.small,
                    weight: JourneyType.bold,
                  ),
                ),
                const TextSpan(text: ' · '),
              ],
              TextSpan(text: reason),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ],
    );
    // Rashad 2026-11-17: at his phone's text size the button fell to its own
    // line and the card took a fifth of the screen. One row now: the whole
    // card opens the step, and its action is said at the row's end in the
    // card's colour, a pill that wraps rather than grows the card.
    return Semantics(
      button: true,
      // The days drawn in the tile are heard here (the tile is skipped).
      label: [
        days == null
            ? eyebrow
            : '$eyebrow · بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}',
        title,
        ?dueAmount,
        reason,
        action,
      ].join('، '),
      excludeSemantics: true,
      onTap: onOpen,
      child: AarastPressable(
        key: ValueKey('aarast-dashboard-next-step-${focus.target.name}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: JourneyBox(
          borderColor: AarastV3Color.line,
          borderWidth: AarastV3Space.hair,
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            children: [
              tile,
              const SizedBox(width: AarastV3Space.x3),
              Expanded(child: words),
              const SizedBox(width: AarastV3Space.x2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _actionMaxWidth),
                child: Container(
                  key: const ValueKey('aarast-next-step-action'),
                  padding: AarastV3Density.tagInsets,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                  ),
                  child: Text(
                    action,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: AarastV3Color.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The action pill's widest: a long label wraps inside it, the step's words
/// keep the rest of the row.
const _actionMaxWidth = 112.0;

/// «5 أيام»: the days left to the due payment, where the icon would be.
class _DaysTile extends StatelessWidget {
  const _DaysTile({
    required this.days,
    required this.color,
    required this.soft,
  });

  final int days;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AarastV3Space.x12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          ),
          // The tile keeps its size when the phone's text is enlarged.
          child: MediaQuery.withNoTextScaling(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$days',
                  style: JourneyType.of(
                    JourneyType.figure,
                    weight: JourneyType.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  arabicCountWord(
                    days,
                    one: 'يوم',
                    two: 'يومين',
                    few: 'أيام',
                    many: 'يوم',
                  ),
                  style: JourneyType.of(
                    JourneyType.tabLabel,
                    weight: JourneyType.bold,
                    color: color,
                    height: 1.2,
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
