import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The journey sheet shell is the prototype's `sheet` (kit.dart): canvas,
/// 28 top radius, 20 / 10 / 20 / 30 padding, a 40×5 handle, 14 to a 22 bold
/// title, a 14 muted subtitle, 16 to the content.
void main() {
  Future<void> open(
    WidgetTester tester, {
    required WidgetBuilder builder,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: viewPadding.bottom);
    tester.view.viewPadding = FakeViewPadding(bottom: viewPadding.bottom);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showJourneySheet<void>(context: context, builder: builder),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('draws the prototype shell', (tester) async {
    await open(
      tester,
      builder: (_) => const JourneySheetBody(
        title: 'تأجيل العرس',
        subtitle: 'نرتب كل شيء على الموعد الجديد',
        children: [SizedBox(key: ValueKey('content'), height: 40)],
      ),
    );

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, AarastV3Color.canvas);
    expect(
      (sheet.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );

    final handleFinder = find.byKey(const ValueKey('journey-sheet-handle'));
    final handle = tester.getRect(handleFinder);
    expect(handle.size, const Size(40, 5));
    final decoration =
        tester.widget<Container>(handleFinder).decoration! as BoxDecoration;
    expect(decoration.color, AarastV3Color.line);

    final body = tester.getRect(find.byType(JourneySheetBody));
    expect(handle.top - body.top, 10);

    final title = tester.widget<Text>(find.text('تأجيل العرس'));
    expect(title.style?.fontSize, 22);
    expect(title.style?.fontWeight, FontWeight.w700);
    final titleRect = tester.getRect(find.text('تأجيل العرس'));
    expect(titleRect.top - handle.bottom, 14);
    expect(body.right - titleRect.right, 20);

    final subtitle = tester.widget<Text>(
      find.text('نرتب كل شيء على الموعد الجديد'),
    );
    expect(subtitle.style?.fontSize, 14);
    expect(subtitle.style?.color, AarastV3Color.textMuted);
    final subtitleRect = tester.getRect(
      find.text('نرتب كل شيء على الموعد الجديد'),
    );

    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(content.top - subtitleRect.bottom, 16);
    expect(body.bottom - content.bottom, 30);
    expect(content.left - body.left, 20);
  });

  testWidgets('the bottom 30 also covers the phone inset', (tester) async {
    await open(
      tester,
      viewPadding: const EdgeInsets.only(bottom: 34),
      builder: (_) => const JourneySheetBody(
        title: 'خططك',
        children: [SizedBox(key: ValueKey('content'), height: 40)],
      ),
    );
    final body = tester.getRect(find.byType(JourneySheetBody));
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(body.bottom - content.bottom, 34);
  });

  testWidgets('tall content scrolls and the bottom action stays', (
    tester,
  ) async {
    await open(
      tester,
      builder: (_) => JourneySheetBody(
        title: 'مهام جاهزة لعرسك',
        bottom: const SizedBox(key: ValueKey('submit'), height: 52),
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(key: ValueKey('row-$i'), height: 48, child: Text('$i')),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    final submit = tester.getRect(find.byKey(const ValueKey('submit')));
    expect(submit.bottom, lessThanOrEqualTo(844));
    expect(find.byKey(const ValueKey('row-39')).hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('row-39')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey('row-39')).hitTestable(), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('submit'))),
      submit,
      reason: 'the action does not scroll away',
    );
  });

  testWidgets('a picker of two goes without a title', (tester) async {
    await open(
      tester,
      builder: (_) => const JourneySheetBody(
        title: null,
        children: [SizedBox(key: ValueKey('content'), height: 40)],
      ),
    );
    final handle = tester.getRect(
      find.byKey(const ValueKey('journey-sheet-handle')),
    );
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(content.top - handle.bottom, 16);
  });
}
