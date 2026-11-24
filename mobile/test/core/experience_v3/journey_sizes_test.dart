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
    expect(_size(tester, 'المال'), JourneyType.hero);
    expect(_size(tester, 'ماشية'), JourneyType.body);
    expect(_size(tester, 'تفاصيل البند'), JourneyType.pageTitle);
    expect(_size(tester, 'قاعة سبأ'), JourneyType.small);
    expect(_size(tester, 'الدفعات القادمة'), JourneyType.lead);
  });

  testWidgets('the question page asks at the hero size', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 560,
          child: JourneyQuestionPage(
            step: 0,
            total: 4,
            question: 'فين العرس؟',
            primaryLabel: 'التالي',
            onPrimary: () {},
            onBack: () {},
            children: const [],
          ),
        ),
      ),
    );
    expect(_size(tester, 'فين العرس؟'), JourneyType.hero);
    // D75: the count is the progress track's spoken label, not drawn text.
    expect(find.text('1 من 4'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'السؤال 1 من 4',
      ),
      findsOneWidget,
    );
    expect(_size(tester, 'التالي'), JourneyType.lead);
  });

  testWidgets('the tab switch is a 48 band of tabs with small bold names', (
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
    // RA-MO-28 (D74): every tab is touched in 48; the selected fill keeps
    // 8 + one 13 line (× 1.35) + 8, centred in it.
    expect(tester.getSize(find.byType(JourneyTabSwitch)).height, 48);
    expect(
      tester.getSize(find.byKey(const ValueKey('journey-tab-0'))).height,
      closeTo(8 + JourneyType.small * AarastV3Line.normal + 8, 0.5),
    );
    final tab = find.ancestor(
      of: find.byKey(const ValueKey('journey-tab-1')),
      matching: find.byType(Semantics),
    );
    expect(tester.getSize(tab.first).height, 48);
    final name = tester.widget<Text>(find.text('الكل'));
    expect(name.style?.fontSize, JourneyType.small);
    expect(name.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('a chip is small bold, about 36 tall', (tester) async {
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
    expect(_size(tester, 'صنعاء'), JourneyType.small);
    final chip = find.ancestor(
      of: find.text('صنعاء'),
      matching: find.byType(Container),
    );
    expect(tester.getSize(chip.first).height, closeTo(AarastV3Size.chip, 0.5));
    // The outlined one carries its 1-point line on each side.
    final outlined = find.ancestor(
      of: find.text('عدن'),
      matching: find.byType(Container),
    );
    expect(
      tester.getSize(outlined.first).height,
      closeTo(AarastV3Size.chip, 0.5),
    );
    // RA-MO-28 (D74): drawn about 36, touched in 48.
    for (final label in ['صنعاء', 'عدن']) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byType(JourneyChip),
      );
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }
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
    expect(_size(tester, 'كلها'), JourneyType.small);
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

  testWidgets(
    'fields: small label, lead value, hero large, no picker chevron',
    (tester) async {
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
      expect(_size(tester, 'اسمك'), JourneyType.small);
      expect(_size(tester, 'موعد العرس'), JourneyType.small);
      expect(_size(tester, 'الخميس 21 يناير'), JourneyType.lead);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.map((field) => field.style?.fontSize), [
        JourneyType.lead,
        JourneyType.hero,
      ]);
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
    },
  );

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
    expect(_size(tester, 'قاعة سبأ'), JourneyType.body);
  });

  // The values themselves, pinned once (D118): the tests above follow the
  // roles, so a role's size could drift (25 to 24, 13.5 to 12.5) and every
  // one of them would still pass.
  test('the type scale and the chip keep their D118 values', () {
    expect(
      [
        JourneyType.homeCount,
        JourneyType.count,
        JourneyType.hero,
        JourneyType.pageTitle,
        JourneyType.lead,
        JourneyType.body,
        JourneyType.small,
        JourneyType.caption,
        JourneyType.badge,
      ],
      [52, 32, 24, 19, 16, 14.5, 12.5, 11, 9],
    );
    expect(AarastV3Size.chip, 36);
  });
}
