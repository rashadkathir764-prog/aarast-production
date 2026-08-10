import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget _host(Widget child, {double width = 320, double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('metric grid is one operable 2x2 surface at 320px', (
    tester,
  ) async {
    var selected = '';
    final items = [
      for (final label in ['المال', 'المهام', 'الضيوف', 'المزوّدون'])
        AarastV3MetricGridData(
          icon: LucideIcons.activity,
          label: label,
          value: '12',
          detail: 'تفصيل حقيقي',
          onTap: () => selected = label,
        ),
    ];

    await tester.pumpWidget(_host(AarastV3MetricGrid(items: items)));

    expect(tester.takeException(), isNull);
    expect(find.byType(AarastV3MetricGrid), findsOneWidget);
    expect(find.text('الضيوف'), findsOneWidget);

    await tester.tap(find.text('الضيوف'));
    expect(selected, 'الضيوف');
  });

  testWidgets('list row keeps its hierarchy at 320px and 2x text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AarastV3ContinuousSurface(
          children: [
            AarastV3ListRow(
              title: 'عنصر طويل لاختبار التخطيط العربي',
              subtitle: 'تفصيل واضح يمكن أن يمتد إلى سطرين دون قص الإجراء.',
              meta: 'يحتاج انتباهك الآن',
              leading: const Icon(LucideIcons.user),
              action: IconButton(
                tooltip: 'المزيد',
                onPressed: () {},
                icon: const Icon(LucideIcons.moreHorizontal),
              ),
            ),
          ],
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('عنصر طويل لاختبار التخطيط العربي'), findsOneWidget);
    expect(find.byTooltip('المزيد'), findsOneWidget);
  });

  testWidgets('swipe actions execute without dismissing the truthful row', (
    tester,
  ) async {
    var completed = 0;
    var edited = 0;
    const itemKey = ValueKey('swipe-row');

    await tester.pumpWidget(
      _host(
        AarastV3SwipeActions(
          itemKey: itemKey,
          primaryLabel: 'إنجاز',
          primaryIcon: LucideIcons.check,
          onPrimary: () async => completed += 1,
          secondaryLabel: 'تعديل',
          secondaryIcon: LucideIcons.pencil,
          onSecondary: () async => edited += 1,
          child: const SizedBox(
            height: 72,
            child: Center(child: Text('مهمة حقيقية')),
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(itemKey), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(find.text('مهمة حقيقية'), findsOneWidget);

    await tester.drag(find.byKey(itemKey), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(edited, 1);
    expect(find.text('مهمة حقيقية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus form remains usable at 320px and 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: AarastV3FormActionBar(
                label: 'حفظ القرار والمتابعة',
                icon: LucideIcons.check,
                onPressed: () {},
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(AarastV3Space.x4),
                child: const Column(
                  children: [
                    AarastV3FocusPrompt(
                      question: 'ما القرار الذي تريد حسمه الآن؟',
                      supportingText:
                          'ابدأ بالمعلومة الأساسية، ويمكنك إضافة التفاصيل لاحقًا.',
                    ),
                    SizedBox(height: AarastV3Space.x4),
                    AarastV3LiveSummary(
                      items: [
                        AarastV3SummaryItem(
                          label: 'القرار',
                          value: 'لم يُكتب بعد',
                        ),
                        AarastV3SummaryItem(label: 'الموعد', value: 'غير محدد'),
                        AarastV3SummaryItem(label: 'المسؤول', value: 'أنا'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما القرار الذي تريد حسمه الآن؟'), findsOneWidget);
    expect(find.text('حفظ القرار والمتابعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
