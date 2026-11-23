// A hero with its own label is read once, and its tag is a button of its own
// (review 2026-11-23): on the guests' tab a screen reader heard the hero
// twice, and «أرسل الدعوة» opened «كم بيحضر؟» instead of sending.

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the hero reads once and its tag sends', (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    var sent = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: JourneyProfileScope(
              profile: JourneyProfile.groom,
              child: JourneyPlanHero(
                figure: '5',
                title: 'أكدوا من 9',
                subtitle: '4 ما ردّوا',
                semanticLabel: '5 أكدوا من 9، 4 ما ردّوا',
                onTap: () => opened++,
                tag: JourneyHeroTag(
                  key: const ValueKey('send-tag'),
                  label: 'أرسل الدعوة لـ12 ضيف',
                  onTap: () => sent++,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Read once: its words are not a second node.
    expect(find.bySemanticsLabel('5 أكدوا من 9، 4 ما ردّوا'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^5\$')), findsNothing);
    expect(find.bySemanticsLabel('أكدوا من 9'), findsNothing);

    // The tag is its own button, and its tap is its own.
    final tag = tester.getSemantics(find.byKey(const ValueKey('send-tag')));
    expect(tag.label, 'أرسل الدعوة لـ12 ضيف');
    expect(tag.hasFlag(SemanticsFlag.isButton), isTrue);
    tester.semantics.tap(find.semantics.byLabel('أرسل الدعوة لـ12 ضيف'));
    await tester.pump();
    expect(sent, 1);
    expect(opened, 0);

    tester.semantics.tap(find.semantics.byLabel('5 أكدوا من 9، 4 ما ردّوا'));
    await tester.pump();
    expect(opened, 1);
    semantics.dispose();
  });
}
