import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan_stage.dart';

void main() {
  final now = DateTime(2026, 8, 9, 23, 45);

  test('stage engine is deterministic at every product boundary', () {
    expect(
      resolveWeddingPlanStage(null, now: now).stage,
      WeddingPlanStage.foundation,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 12, 8), now: now).stage,
      WeddingPlanStage.foundation,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 12, 7), now: now).stage,
      WeddingPlanStage.planning,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 9, 9), now: now).stage,
      WeddingPlanStage.planning,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 9, 8), now: now).stage,
      WeddingPlanStage.finalMonth,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 8, 17), now: now).stage,
      WeddingPlanStage.finalMonth,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 8, 16), now: now).stage,
      WeddingPlanStage.finalWeek,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 8, 10), now: now).stage,
      WeddingPlanStage.finalWeek,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 8, 9), now: now).stage,
      WeddingPlanStage.weddingDay,
    );
    expect(
      resolveWeddingPlanStage(DateTime(2026, 8, 8), now: now).stage,
      WeddingPlanStage.wrapUp,
    );
  });

  test('stage engine exposes compact truthful Arabic guidance', () {
    final stage = resolveWeddingPlanStage(DateTime(2026, 8, 14), now: now);

    expect(stage.daysUntilWedding, 5);
    expect(stage.compactLabel, 'الأسبوع الأخير');
    expect(stage.headline, isNotEmpty);
    expect(stage.guidance, contains('المهام الحرجة'));
    expect(stage.isWeddingWindow, isTrue);
  });
}
