part of 'aarast_dashboard_view.dart';

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
