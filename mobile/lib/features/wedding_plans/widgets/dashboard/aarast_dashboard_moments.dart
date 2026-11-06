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
                height: 6,
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
