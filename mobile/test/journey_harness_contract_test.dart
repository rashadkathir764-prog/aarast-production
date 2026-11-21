import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_journey_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/journeys/support/journey_harness.dart';

void main() {
  testWidgets('offline money must match the actual online figure and unit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Widget screen(String figure, [String unit = 'مليون ر.ي']) => MaterialApp(
      home: JourneyPlanHero(
        key: const ValueKey('money-share-hero'),
        figure: figure,
        title: unit,
      ),
    );
    final walk = JourneyWalk(tester, 'offline-money-contract');
    await tester.pumpWidget(screen('2.2'));
    await walk.rememberMoneyHero();
    await walk.expectRememberedMoneyHero();
    await tester.pumpWidget(screen('1.6'));
    await expectLater(walk.expectRememberedMoneyHero(), throwsStateError);
    await tester.pumpWidget(screen('2.2', 'ألف ر.ي'));
    await expectLater(walk.expectRememberedMoneyHero(), throwsStateError);
    await (await SharedPreferences.getInstance()).clear();
    await expectLater(walk.expectRememberedMoneyHero(), throwsStateError);
  });

  testWidgets(
    'a status check belongs to its own surface and rejects a missing surface',
    (tester) async {
      Widget screen({required bool inactiveHall}) => MaterialApp(
        home: Column(
          children: [
            Column(
              key: const ValueKey('hall'),
              children: [
                const Text('صالة الياسمين'),
                if (inactiveHall) const Text('غير مفعّل'),
              ],
            ),
            const Column(children: [Text('مصور الحارة'), Text('غير مفعّل')]),
          ],
        ),
      );
      final walk = JourneyWalk(tester, 'surface-contract');
      final hall = find.byKey(const ValueKey('hall'));
      await tester.pumpWidget(screen(inactiveHall: false));
      expect(walk.expectNotSee('غير مفعّل', within: hall), isTrue);
      await tester.pumpWidget(screen(inactiveHall: true));
      expect(
        () => walk.expectNotSee('غير مفعّل', within: hall),
        throwsStateError,
      );
      expect(
        () => walk.expectNotSee(
          'غير مفعّل',
          within: find.byKey(const ValueKey('missing')),
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'journey text accepts nonbreaking spaces but keeps exact figures',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('باقي المهر 1\u00a0مليون\u00a0ر.ي · عليك 1.6\u00a0مليون'),
        ),
      );
      final walk = JourneyWalk(tester, 'text-contract');
      expect(walk.sees('باقي المهر 1 مليون'), isTrue);
      expect(walk.sees('عليك 1.6 مليون'), isTrue);
      expect(walk.sees('عليك 1.7 مليون'), isFalse);
      expect(walk.sees('باقي المهر 2 مليون'), isFalse);
    },
  );
}
