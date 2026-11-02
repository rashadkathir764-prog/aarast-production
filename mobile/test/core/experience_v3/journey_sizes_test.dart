import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// D74: the kit draws the type scale set for the phones people hold (D30's
/// headings a step down).
/// A phone's content column (390 wide, 16 each side), as screens use them.
Widget _host(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 358,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        ),
      ),
    ),
  );
}

double _size(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  testWidgets('headings take the design sizes', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            JourneyTabHeader(title: 'المال', status: 'ماشية'),
            JourneySubHeader(title: 'تفاصيل البند', subtitle: 'قاعة سبأ'),
            JourneySectionTitle('الدفعات القادمة'),
          ],
        ),
      ),
    );
    expect(_size(tester, 'المال'), 24);
    expect(_size(tester, 'ماشية'), 14.5);
    expect(_size(tester, 'تفاصيل البند'), 18);
    expect(_size(tester, 'قاعة سبأ'), 13);
    expect(_size(tester, 'الدفعات القادمة'), 16);
  });

  testWidgets('the question page asks at 25', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 560,
          child: JourneyQuestionPage(
            step: 0,
            total: 4,
            question: 'وين العرس؟',
            primaryLabel: 'التالي',
            onPrimary: () {},
            onBack: () {},
            children: const [],
          ),
        ),
      ),
    );
    expect(_size(tester, 'وين العرس؟'), JourneyType.question);
    expect(_size(tester, 'وين العرس؟'), 25);
    // D75: the count is the progress track's spoken label, not drawn text.
    expect(find.text('1 من 4'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'السؤال 1 من 4',
      ),
      findsOneWidget,
    );
    expect(_size(tester, 'التالي'), 16);
  });

  testWidgets('the tab switch is about 44 tall with 13 bold names', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        JourneyTabSwitch(
          labels: const ['الكل', 'الرجال', 'النساء'],
          selected: 0,
          onSelected: (_) {},
        ),
      ),
    );
    // 4 + 8 + one 13 line (× 1.35) + 8 + 4, on the grid (D74).
    expect(
      tester.getSize(find.byType(JourneyTabSwitch)).height,
      closeTo(4 + 8 + 13 * 1.35 + 8 + 4, 0.5),
    );
    final name = tester.widget<Text>(find.text('الكل'));
    expect(name.style?.fontSize, 13);
    expect(name.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('a chip is 13.5 bold, 14 / 9 inside, about 36 tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Wrap(
          children: [
            JourneyChip(label: 'صنعاء', selected: true, onTap: () {}),
            JourneyChip(label: 'عدن', onTap: () {}),
          ],
        ),
      ),
    );
    expect(_size(tester, 'صنعاء'), 13.5);
    final chip = find.ancestor(
      of: find.text('صنعاء'),
      matching: find.byType(Container),
    );
    expect(
      tester.getSize(chip.first).height,
      closeTo(9 + 13.5 * 1.35 + 9, 0.5),
    );
    // The outlined one carries its 1-point line on each side.
    final outlined = find.ancestor(
      of: find.text('عدن'),
      matching: find.byType(Container),
    );
    expect(
      tester.getSize(outlined.first).height,
      closeTo(1 + 8 + 13.5 * 1.35 + 8 + 1, 0.5),
    );
  });

  testWidgets('a section link is plain words and keeps the row height', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            const JourneySectionTitle('الدفعات', key: ValueKey('plain')),
            JourneySectionTitle(
              'القادمة',
              key: const ValueKey('linked'),
              action: 'كلها',
              onAction: () => taps++,
            ),
          ],
        ),
      ),
    );
    expect(_size(tester, 'كلها'), 13.5);
    expect(
      tester.getSize(find.byKey(const ValueKey('linked'))).height,
      tester.getSize(find.byKey(const ValueKey('plain'))).height,
    );
    await tester.tap(find.text('كلها'));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.text('كلها')),
      isSemantics(label: 'كلها', isButton: true, hasTapAction: true),
    );
  });

  testWidgets('fields: 12 label, 16 value, 24 large, no picker chevron', (
    tester,
  ) async {
    final name = TextEditingController(text: 'محمد');
    final budget = TextEditingController(text: '10,000,000');
    addTearDown(name.dispose);
    addTearDown(budget.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            JourneyTextField(label: 'اسمك', controller: name),
            JourneyTextField(
              label: 'ميزانية عرسك',
              controller: budget,
              large: true,
            ),
            JourneyPickerField(
              label: 'موعد العرس',
              value: 'الخميس 21 يناير',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(_size(tester, 'اسمك'), 12);
    expect(_size(tester, 'موعد العرس'), 12);
    expect(_size(tester, 'الخميس 21 يناير'), 16);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.map((field) => field.style?.fontSize), [16, 24]);
    expect(
      find.descendant(
        of: find.byType(JourneyPickerField),
        matching: find.byIcon(LucideIcons.chevronLeft),
      ),
      findsNothing,
    );
    // The one field padding (AarastV3Field, D74).
    final box = find
        .ancestor(of: find.text('اسمك'), matching: find.byType(Container))
        .first;
    expect(tester.widget<Container>(box).padding, AarastV3Field.padding);
  });

  testWidgets('a list row keeps its subtitle to one line', (tester) async {
    await tester.pumpWidget(
      _host(
        const JourneyListRow(
          icon: LucideIcons.building2,
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
          title: 'قاعة سبأ',
          subtitle: 'الدفعة الثانية · 500 ألف · قبل العرس بأسبوع',
        ),
      ),
    );
    final subtitle = tester.widget<Text>(
      find.text('الدفعة الثانية · 500 ألف · قبل العرس بأسبوع'),
    );
    expect(subtitle.maxLines, 1);
    expect(_size(tester, 'قاعة سبأ'), 14.5);
  });
}
