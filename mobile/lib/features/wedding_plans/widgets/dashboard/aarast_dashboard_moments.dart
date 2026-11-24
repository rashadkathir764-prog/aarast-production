part of 'aarast_dashboard_view.dart';

/// b01's countdown in words. The drawn line carries the counted word alone,
/// because the days sit beside it in 52 point: «أيام» has to follow the
/// number's own rule (arabicCountWord) and never read «3 يوم». The spoken
/// line carries the number with it, so a reader hears one line instead of
/// the figure twice.
({String drawn, String spoken}) homeCountdownWords(int? days) {
  if (days == null) return (drawn: '', spoken: '');
  if (days > 0) {
    final word = arabicCountWord(
      days,
      one: 'يوم واحد',
      two: 'يومين',
      few: 'أيام',
      many: 'يوم',
    );
    return (drawn: '$word على عرسك', spoken: '${arabicDays(days)} على عرسك');
  }
  if (days == 0) return (drawn: 'اليوم عرسك', spoken: 'اليوم عرسك');
  // The header already congratulates by name (b07), so the moment box states
  // the day instead of saying «ألف مبروك» a second time.
  return (drawn: 'عرسك كان', spoken: 'عرسك كان');
}

/// The design's five moments of the wedding (b01, b02, b04, b05, b07).
const _homeMoments = [
  'البداية',
  'التجهيز',
  'أسبوع العرس',
  'يوم العرس',
  'بعد العرس',
];

/// Which of [_homeMoments] the home is in: «البداية» while the first steps
/// lead the home (b01), «التجهيز» after them (b02), then the wedding week,
/// the day and after it by the date.
int _homeMoment(WeddingPlanStage stage, {required bool startingOut}) {
  return switch (stage) {
    WeddingPlanStage.wrapUp => 4,
    WeddingPlanStage.weddingDay => 3,
    WeddingPlanStage.finalWeek => 2,
    _ => startingOut ? 0 : 1,
  };
}

/// What moves the plan into each of [_homeMoments]: the basics, then the
/// calendar (D112's wedding window is the seven days before the day,
/// `weddingWeekDays`).
const _homeMomentWhy = [
  'لين تحط الميزانية وأول بند وأول مهمة وأول ضيف',
  'بعد الأساسيات، لين يبقى أسبوع على العرس',
  'الأيام السبعة قبل العرس',
  'يوم العرس نفسه',
  'بعده: الباقي من الدفعات، وتقييم المزودين',
];

/// The five moments named, the plan's own marked (critique ر4).
void _showMoments(BuildContext context, int current) {
  showJourneySheet<void>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const ValueKey('aarast-dashboard-moments-sheet'),
      title: 'مراحل العرس',
      subtitle: 'تنتقل بينها لحالها، بالأيام وبما تسجّله.',
      children: [
        JourneyList(
          children: [
            for (var index = 0; index < _homeMoments.length; index++)
              JourneyListRow(
                key: ValueKey('aarast-dashboard-moment-row-$index'),
                icon: index < current
                    ? LucideIcons.check
                    : index == current
                    ? LucideIcons.mapPin
                    : LucideIcons.circle,
                color: index == current
                    ? AarastV3Color.brandAccentStrong
                    : index < current
                    ? AarastV3Color.mint
                    : AarastV3Color.textMuted,
                soft: index == current
                    ? AarastV3Color.brandAccentSoft
                    : index < current
                    ? AarastV3Color.mintSoft
                    : AarastV3Color.paperQuiet,
                title: index == current
                    ? '${_homeMoments[index]} · أنت هنا'
                    : _homeMoments[index],
                subtitleMaxLines: 2,
                subtitle: _homeMomentWhy[index],
              ),
          ],
        ),
      ],
    ),
  );
}

/// The five moments as five equal bars: the passed ones white, the
/// [current] one saffron, the ones ahead a faint white (b01, b02).
class _StagePath extends StatelessWidget {
  const _StagePath({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var index = 0; index < _homeMoments.length; index++) ...[
            if (index > 0) const SizedBox(width: AarastV3Space.x1),
            Expanded(
              child: Container(
                key: ValueKey('aarast-dashboard-moment-$index'),
                height: AarastV3Size.bar,
                decoration: BoxDecoration(
                  color: index == current
                      ? AarastV3Color.saffron
                      : index < current
                      ? AarastV3Color.onPrimary
                      : AarastV3Color.onPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AarastV3Radius.xs),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// D112 (Q-20): the wedding's week and day hide the money and the tasks;
/// what is due today still shows, one line each: the payment whose day is
/// today, and today's tasks.
class _TodayDue extends StatelessWidget {
  const _TodayDue({
    required this.payment,
    required this.paymentDays,
    required this.tasks,
    required this.currency,
    required this.amountsHidden,
    required this.onOpenPayment,
    required this.onOpenTasks,
  });

  final DashboardNextPaymentSchedule? payment;

  /// Days from today to [payment]'s day in Sana'a: 0 today, negative late.
  final int? paymentDays;
  final int tasks;
  final String currency;
  final bool amountsHidden;
  final VoidCallback? onOpenPayment;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final due = payment;
    return JourneyList(
      key: const ValueKey('aarast-home-today'),
      children: [
        if (due != null)
          JourneyListRow(
            key: const ValueKey('aarast-home-today-payment'),
            icon: LucideIcons.wallet,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            title: _paymentWhen(paymentDays ?? 0),
            subtitle: [
              if (due.title.trim().isNotEmpty) due.title.trim(),
              // One payment, written as the next step writes it: whole
              // unless shortening loses nothing.
              amountsHidden
                  ? '••••'
                  : sumSafeMoneyParts(
                      dashboardAmount(due.amount) ?? 0,
                      currencyCode: currency,
                    ).plainText,
            ].join(' · '),
            onTap: onOpenPayment,
          ),
        if (tasks > 0)
          JourneyListRow(
            key: const ValueKey('aarast-home-today-tasks'),
            icon: LucideIcons.listChecks,
            color: context.accent.primary,
            soft: context.accent.primarySoft,
            title: 'مهام اليوم',
            subtitle: arabicCount(
              tasks,
              one: 'مهمة وحدة',
              two: 'مهمتين',
              few: 'مهام',
              many: 'مهمة',
            ),
            onTap: onOpenTasks,
          ),
      ],
    );
  }
}

/// «دفعة اليوم», «دفعة بكرة», «دفعة بعد 3 أيام», «دفعة متأخرة 3 أيام».
String _paymentWhen(int days) {
  String count(int n) =>
      arabicCount(n, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم');
  if (days < 0) return 'دفعة متأخرة ${count(-days)}';
  return switch (days) {
    0 => 'دفعة اليوم',
    1 => 'دفعة بكرة',
    2 => 'دفعة بعد يومين',
    _ => 'دفعة بعد ${count(days)}',
  };
}
