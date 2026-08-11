import 'dart:ui' show SemanticsAction, Tristate;

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_button.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(Widget child, {double textScale = 1}) {
    return MaterialApp(
      theme: AppTheme.light(),
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: appChild!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets(
    'AarastPressable participates in focus traversal and activates by keyboard',
    (tester) async {
      var activations = 0;
      const pressableKey = Key('keyboard-pressable');

      await tester.pumpWidget(
        harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('قبل')),
              AarastPressable(
                key: pressableKey,
                semanticLabel: 'فتح تفاصيل الخطة',
                onTap: () => activations += 1,
                child: const SizedBox(
                  width: 180,
                  height: 56,
                  child: Center(child: Text('تفاصيل الخطة')),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('بعد')),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final node = tester.getSemantics(find.byKey(pressableKey));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      expect(node.flagsCollection.isFocused, Tristate.isTrue);
      expect(node.label, 'فتح تفاصيل الخطة');
      final focusIndicator = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(pressableKey),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (focusIndicator.foregroundDecoration as BoxDecoration).border,
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(activations, 2);

      await tester.tap(find.byKey(pressableKey));
      await tester.pump();

      expect(activations, 3);
    },
  );

  testWidgets('AarastPressable removes scale animation for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AarastPressable(
            onTap: _noop,
            child: SizedBox(width: 180, height: 56),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
  });

  testWidgets('AarastPressable exposes and runs the long-press action', (
    tester,
  ) async {
    var longPresses = 0;
    const pressableKey = Key('long-pressable');

    await tester.pumpWidget(
      harness(
        AarastPressable(
          key: pressableKey,
          semanticLabel: 'إضافة',
          longPressSemanticLabel: 'فتح آخر إجراء إضافة مستخدم',
          onTap: _noop,
          onLongPress: () => longPresses += 1,
          child: const SizedBox(width: 120, height: 56),
        ),
      ),
    );

    await tester.longPress(find.byKey(pressableKey));
    await tester.pump();

    expect(longPresses, 1);
    final node = tester.getSemantics(find.byKey(pressableKey));
    expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
  });

  testWidgets('AarastPressable exposes its disabled button state', (
    tester,
  ) async {
    const pressableKey = Key('disabled-pressable');

    await tester.pumpWidget(
      harness(
        const AarastPressable(
          key: pressableKey,
          semanticLabel: 'خيار غير متاح',
          onTap: null,
          child: SizedBox(
            width: 180,
            height: 56,
            child: Center(child: Text('خيار غير متاح')),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byKey(pressableKey));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.flagsCollection.isFocused, Tristate.none);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('AarastButton keeps an accessible name while loading', (
    tester,
  ) async {
    const buttonKey = Key('loading-button');

    await tester.pumpWidget(
      harness(
        AarastButton(
          key: buttonKey,
          label: 'حفظ التغييرات',
          isLoading: true,
          onPressed: () {},
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('حفظ التغييرات'));
    expect(node.label, 'حفظ التغييرات');
    expect(node.value, 'جارٍ التنفيذ');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('AarastButton stays RTL-safe at 320px with large Arabic text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    const label = 'حفظ جميع التغييرات والمتابعة إلى الخطوة التالية';

    await tester.pumpWidget(
      harness(
        Padding(
          padding: const EdgeInsets.all(16),
          child: AarastButton(
            label: label,
            icon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
        ),
        textScale: 1.8,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(label), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.arrow_forward_rounded)).dx,
      greaterThan(tester.getCenter(find.text(label)).dx),
    );
  });
}

void _noop() {}
