import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget _host(Widget child, {double width = 320, double textScale = 1}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Material(
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a bar fills its height', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 200,
          child: JourneyBar(value: 0.25, color: AarastV3Color.primary),
        ),
      ),
    );
    final filled = tester.getSize(
      find
          .descendant(
            of: find.byType(JourneyBar),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(filled.height, 6);
    final bar = tester.getSize(find.byType(JourneyBar));
    expect(filled.width, closeTo(bar.width * 0.25, 1));
  });

  // D8: one type scale. A size is a role from JourneyType, never a number
  // picked on a screen, so screens cannot drift apart again.
  test('journey text takes its size from the type scale', () {
    final literal = RegExp(r'JourneyType\.of\(\s*\d');
    final offenders = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (literal.hasMatch(line)) '${file.path}:${index + 1}',
    ];
    expect(offenders, isEmpty, reason: offenders.join(', '));
  });

  testWidgets('kit pieces stay inside 320 px with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final title = TextEditingController(text: 'محمد');
    addTearDown(title.dispose);
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const JourneyTabHeader(
                title: 'المال',
                status: 'ماشية، بس ناقصك 2.5 مليون',
              ),
              const JourneySubHeader(
                title: 'تفاصيل البند',
                subtitle: 'قاعة سبأ',
              ),
              const JourneySectionTitle('الدفعات القادمة', action: 'كلها'),
              JourneyChoiceCard(
                title: 'أنشئ خطتك',
                subtitle: 'لعرسك أنت، عريس أو عروسة',
                leading: const JourneyIconTile(
                  icon: LucideIcons.heart,
                  color: AarastV3Color.primary,
                  soft: AarastV3Color.primarySoft,
                ),
                selected: true,
                onTap: () {},
              ),
              JourneyList(
                children: [
                  JourneyListRow(
                    icon: LucideIcons.building2,
                    color: AarastV3Color.cobalt,
                    soft: AarastV3Color.cobaltSoft,
                    title: 'قاعة سبأ',
                    subtitle: 'الدفعة الثانية · 500 ألف',
                    trailing: const JourneyTag(
                      label: 'محجوز',
                      color: AarastV3Color.mint,
                      soft: AarastV3Color.mintSoft,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
              JourneyTextField(label: 'اسمك', controller: title),
              JourneyPickerField(
                label: 'موعد العرس',
                value: 'الخميس 21 يناير',
                onTap: () {},
              ),
              const JourneyNote(
                text: 'قبل رمضان بـ 18 يوم، والحجوزات تكثر قبل رمضان.',
              ),
              JourneyButton(
                label: 'التالي',
                onPressed: () {},
                expand: true,
                large: true,
              ),
              const JourneyBar(value: 0.4, color: AarastV3Color.primary),
              const JourneySegments(total: 4, done: 1),
              const JourneyWordmark(),
            ],
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('buttons and choices expose their meaning to screen readers', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            JourneyButton(label: 'ابدأ', onPressed: () => taps++),
            const JourneyButton(label: 'التالي', onPressed: null),
            JourneyChip(label: 'صنعاء', selected: true, onTap: () {}),
            const JourneyRoundButton(
              icon: LucideIcons.search,
              tooltip: 'بحث',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('ابدأ'));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.text('التالي')),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        label: 'التالي',
      ),
    );
    expect(find.byTooltip('بحث'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('صنعاء')),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        label: 'صنعاء',
        hasTapAction: true,
      ),
    );
  });

  testWidgets('a level switch picks one word and reads it with its row', (
    tester,
  ) async {
    var picked = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => JourneyLevelSwitch(
            options: const ['لا', 'يشوف', 'يعدّل'],
            selected: picked,
            semanticLabel: 'المال',
            onChanged: (value) => setState(() => picked = value),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('لا')),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        label: 'المال: لا',
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('يعدّل'));
    await tester.pump();
    expect(picked, 2);
    expect(
      tester.widget<Text>(find.text('يعدّل')).style?.color,
      AarastV3Color.primary,
    );
    expect(
      tester.widget<Text>(find.text('لا')).style?.color,
      AarastV3Color.textMuted,
    );
  });

  testWidgets('the question page counts steps from one', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 800,
          child: JourneyQuestionPage(
            step: 1,
            total: 4,
            question: 'وين العرس؟',
            primaryLabel: 'التالي',
            onPrimary: null,
            onBack: () {},
            skipLabel: 'أكمل بدون ميزانية',
            onSkip: () {},
            children: const [Text('محتوى')],
          ),
        ),
      ),
    );
    // D75: the count from one is spoken on the progress track, not drawn.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'السؤال 2 من 4',
      ),
      findsOneWidget,
    );
    expect(find.text('2 من 4'), findsNothing);
    expect(find.text('أكمل بدون ميزانية'), findsOneWidget);
  });
}
