import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan_stage.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_stage_domain_guidance.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/wedding_stage_context_line.dart';

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

  test('every product stage has domain guidance without invented counts', () {
    final dates = <DateTime?>[
      null,
      DateTime(2026, 10, 1),
      DateTime(2026, 8, 30),
      DateTime(2026, 8, 14),
      DateTime(2026, 8, 9),
      DateTime(2026, 8, 8),
    ];

    for (final date in dates) {
      final stage = resolveWeddingPlanStage(date, now: now);
      for (final domain in WeddingStageDomain.values) {
        final guidance = resolveWeddingStageDomainGuidance(stage, domain);
        expect(guidance.label, isNotEmpty);
        expect(guidance.message, isNotEmpty);
        expect(
          RegExp(r'\d').hasMatch('${guidance.label}${guidance.message}'),
          isFalse,
          reason: 'Stage guidance must not invent counts for $domain.',
        );
      }
    }
  });

  testWidgets('stage context stays compact and semantic at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stage = resolveWeddingPlanStage(DateTime(2026, 8, 14), now: now);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WeddingStageContextLine(
              stage: stage,
              domain: WeddingStageDomain.guests,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('stage-context-guests')), findsOneWidget);
    expect(find.textContaining('الأسبوع الأخير'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
