import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 700);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: app!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // w42: the four states of every list, at 320 px with doubled text.
  testWidgets('loading shows the list shape', (tester) async {
    await _pump(
      tester,
      const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.guests,
      ),
    );
    expect(find.byKey(const ValueKey('journey-list-loading')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty names what is missing and offers the first step', (
    tester,
  ) async {
    var added = 0;
    await _pump(
      tester,
      JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.guests,
        emptyTitle: 'ما أضفت ضيوف',
        emptyAction: 'أضف أول ضيف',
        onEmptyAction: () => added++,
      ),
    );
    expect(find.text('ما أضفت ضيوف'), findsOneWidget);
    await tester.tap(find.text('أضف أول ضيف'));
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error says the measured reason under the title', (tester) async {
    await _pump(
      tester,
      const JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.guests,
        errorMessage: 'الخادم أقدم من التطبيق.',
      ),
    );
    expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
    expect(find.text('الخادم أقدم من التطبيق.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error offers one retry', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.guests,
        onRetry: () => retried++,
      ),
    );
    expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
    await tester.tap(find.text('جرّب مرة ثانية'));
    expect(retried, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline with nothing kept says so and offers nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      const JourneyListState(
        phase: JourneyListPhase.offline,
        section: JourneySection.guests,
      ),
    );
    expect(find.text('ما في نت، وما عندك نسخة محفوظة'), findsOneWidget);
    expect(find.byType(JourneyButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error over kept rows is a notice, never a wipe', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          JourneyListNotice(offline: false, onRetry: () {}),
          const Text('ضيف محفوظ'),
        ],
      ),
    );
    expect(find.text('ما قدرنا نحدّثها، وهذي آخر نسخة'), findsOneWidget);
    expect(find.text('ضيف محفوظ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline over kept rows reads as view only', (tester) async {
    await _pump(tester, const JourneyListNotice(offline: true));
    expect(find.text('آخر نسخة محفوظة · تشوف بس'), findsOneWidget);
    expect(find.text('جرّب مرة ثانية'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
