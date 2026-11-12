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
            size: AarastV3Space.x12,
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
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ],
    );
    final button = JourneyButton(label: action, onPressed: onOpen);
    return JourneyBox(
      key: ValueKey('aarast-dashboard-next-step-${focus.target.name}'),
      borderColor: AarastV3Color.line,
      borderWidth: AarastV3Space.hair,
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // One row when the button leaves the words room: its label is
          // short, the text is not enlarged and the card is a phone's width.
          final oneRow =
              action.characters.length <= _inlineActionLetters &&
              MediaQuery.textScalerOf(context).scale(1) <= 1 &&
              constraints.maxWidth >= _inlineActionWidth;
          if (oneRow) {
            return Row(
              children: [
                tile,
                const SizedBox(width: AarastV3Space.x3),
                Expanded(child: words),
                const SizedBox(width: AarastV3Space.x3),
                button,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  tile,
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(child: words),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              Align(alignment: AlignmentDirectional.centerStart, child: button),
            ],
          );
        },
      ),
    );
  }
}

/// The longest action label that sits at the end of the next step's row,
/// and the card width from which it does (a 360 phone's content column).
const _inlineActionLetters = 12;
const _inlineActionWidth = 300.0;

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
