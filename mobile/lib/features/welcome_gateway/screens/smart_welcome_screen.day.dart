part of 'smart_welcome_screen.dart';

/// The wedding day inside a chosen month: a Saturday-first week, each day
/// with its Hijri date under it, Ramadan days marked, past days closed.
class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.month,
    required this.selected,
    required this.today,
  });

  final DateTime month;
  final DateTime? selected;
  final DateTime today;

  static const _weekdays = [
    'سبت',
    'أحد',
    'اثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
  ];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday: Monday 1 to Sunday 7; Saturday opens the week.
    final lead = (first.weekday + 1) % 7;
    final firstHijri = HijriDate.fromGregorian(first);
    final lastHijri = HijriDate.fromGregorian(
      DateTime(month.year, month.month, days),
    );
    final hijriSpan = firstHijri == null || lastHijri == null
        ? null
        : firstHijri.month == lastHijri.month
        ? '${firstHijri.monthName} ${firstHijri.year}'
        : '${firstHijri.monthName} · ${lastHijri.monthName} ${lastHijri.year}';
    return JourneySheetBody(
      title: 'يوم العرس في ${arabicMonthName(month.month)} ${month.year}',
      subtitle: hijriSpan,
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      style: JourneyType.of(
                        JourneyType.caption,
                        weight: JourneyType.bold,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row * 7 < lead + days; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _dayCell(context, row * 7 + column - lead + 1, days),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 56);
    final date = DateTime(month.year, month.month, day);
    final past = date.isBefore(today);
    final chosen = selected != null && DateUtils.isSameDay(selected, date);
    final hijri = HijriDate.fromGregorian(date);
    final ramadan = hijri?.month == 9;
    final fg = chosen
        ? AarastV3Color.onPrimary
        : past
        ? AarastV3Color.textFaint
        : AarastV3Color.ink;
    final hijriColor = chosen
        ? AarastV3Color.onPrimaryMuted
        : past
        ? AarastV3Color.textFaint
        : ramadan
        ? AarastV3Color.brandAccentStrong
        : AarastV3Color.textMuted;
    void pick() => Navigator.of(context).pop(date);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: !past,
        selected: chosen,
        enabled: !past,
        label: [
          formatArabicWeekdayDayMonth(date),
          ?hijri?.dayAndMonth,
          if (ramadan) 'في رمضان',
        ].join('، '),
        onTap: past ? null : pick,
        excludeSemantics: true,
        child: AarastPressable(
          onTap: past ? null : pick,
          selected: chosen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: chosen ? AarastV3Color.primary : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: fg,
                  ),
                ),
                if (hijri != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    // A new Hijri month names itself on its first day.
                    child: Text(
                      hijri.day == 1 ? '1 ${hijri.monthName}' : '${hijri.day}',
                      style: JourneyType.of(
                        JourneyType.caption,
                        color: hijriColor,
                      ),
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
