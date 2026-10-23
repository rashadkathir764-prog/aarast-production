import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/models/money_starter_catalog.dart';
import 'package:aarast_mobile/features/catalogs/models/reference_catalog.dart';
import 'package:aarast_mobile/features/finance/widgets/money_starter_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('money starter catalog', () {
    test('groom and bride catalogs stay distinct and duplicate-free', () {
      final groom = moneyStarterCatalogFor(MoneyStarterPersona.groom);
      final bride = moneyStarterCatalogFor(MoneyStarterPersona.bride);

      final groomNames = groom.categories.map((item) => item.name).toList();
      final brideNames = bride.categories.map((item) => item.name).toList();

      expect(groomNames, contains('بدلة العريس'));
      expect(groomNames, isNot(contains('فستان العروسة')));
      expect(brideNames, contains('فستان العروسة'));
      expect(brideNames, isNot(contains('بدلة العريس')));
      expect(groomNames.toSet().length, groomNames.length);
      expect(brideNames.toSet().length, brideNames.length);
      // Includes the Yemeni essentials: kiswa and qat (groom), naqsh (bride).
      // The mahr is outside the budget (DECISIONS 2026-10-22, C1).
      expect(groom.recommendedIds.length, 11);
      expect(bride.recommendedIds.length, 11);
    });

    test('persona parsing is safe for backend and local values', () {
      expect(moneyStarterPersonaFromCode('GROOM'), MoneyStarterPersona.groom);
      expect(moneyStarterPersonaFromCode('bride'), MoneyStarterPersona.bride);
      expect(
        moneyStarterPersonaFromCode('HELPER'),
        MoneyStarterPersona.neutral,
      );
      expect(moneyStarterPersonaFromCode(null), MoneyStarterPersona.neutral);
    });

    test('published managed catalog replaces only the matching persona', () {
      const managed = ManagedReferenceCatalog(
        key: 'money.starter.categories',
        nameAr: 'تصنيفات الميزانية',
        version: 7,
        items: [
          ManagedReferenceCatalogItem(
            key: 'groom-live-category',
            nameAr: 'تصنيف منشور للعريس',
            groupKey: 'groom-live',
            groupNameAr: 'مجموعة منشورة',
            groupSubtitleAr: 'قادمة من لوحة الإدارة.',
            icon: 'gift',
            sortOrder: 10,
            showForGroom: true,
            showForBride: false,
            showForCustomer: true,
            showForProvider: false,
            isRecommended: true,
          ),
        ],
      );

      final groom = moneyStarterCatalogFromManaged(
        managed,
        MoneyStarterPersona.groom,
      );
      final bride = moneyStarterCatalogFromManaged(
        managed,
        MoneyStarterPersona.bride,
      );

      expect(groom.categories.map((item) => item.name), ['تصنيف منشور للعريس']);
      expect(groom.groups.single.title, 'مجموعة منشورة');
      expect(
        bride.categories.map((item) => item.name),
        contains('فستان العروسة'),
      );
    });
  });

  testWidgets('bride starter adds a truthful custom category', (tester) async {
    List<String>? submitted;
    await _pumpStarter(
      tester,
      persona: MoneyStarterPersona.bride,
      onSubmit: (categories) async {
        submitted = categories;
        return true;
      },
    );

    expect(find.text('جهّزي ميزانية فرحتك'), findsOneWidget);
    expect(find.text('فستان العروسة'), findsOneWidget);
    expect(find.text('بدلة العريس'), findsNothing);
    expect(find.text('تجهيز الميزانية · 11'), findsOneWidget);

    final addCustom = find.byKey(const ValueKey('money-starter-add-custom'));
    await tester.scrollUntilVisible(
      addCustom,
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(addCustom);
    await tester.pumpAndSettle();

    final customField = find.byKey(
      const ValueKey('money-starter-custom-field'),
    );
    await tester.enterText(customField, 'فستان العروسة');
    await tester.tap(find.byTooltip('أضف البند'));
    await tester.pump();
    expect(find.text('هذا البند موجود.'), findsOneWidget);

    await tester.enterText(customField, 'فرقة نسائية خاصة');
    await tester.tap(find.byTooltip('أضف البند'));
    await tester.pumpAndSettle();
    expect(find.text('فرقة نسائية خاصة'), findsOneWidget);
    expect(find.text('تجهيز الميزانية · 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('money-starter-submit')));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted, contains('فرقة نسائية خاصة'));
    expect(submitted, contains('فستان العروسة'));
    expect(submitted, isNot(contains('بدلة العريس')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the action bar sits on the tab bottom edge, not over the list', (
    tester,
  ) async {
    // Seen in the running app: lifted by 94 for the old shell that drew the
    // tab under its navigation bar, the bar floated with list rows below it.
    await _pumpStarter(
      tester,
      persona: MoneyStarterPersona.groom,
      onSubmit: (_) async => true,
    );

    final manual = find.byKey(const ValueKey('money-starter-manual'));
    expect(manual, findsOneWidget);
    expect(tester.getBottomLeft(manual).dy, greaterThan(900 - 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starter remains usable at 320px and 2.0 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MoneyStarterSetup(
                catalog: moneyStarterCatalogFor(MoneyStarterPersona.groom),
                loading: false,
                onRefresh: () async {},
                onManualSetup: () {},
                onSubmit: (_) async => true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final manual = find.byKey(const ValueKey('money-starter-manual'));
    await tester.scrollUntilVisible(
      manual,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(manual, findsOneWidget);
    expect(find.byKey(const ValueKey('money-starter-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpStarter(
  WidgetTester tester, {
  required MoneyStarterPersona persona,
  required MoneyStarterSubmit onSubmit,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AarastV3Color.canvas,
          body: MoneyStarterSetup(
            catalog: moneyStarterCatalogFor(persona),
            loading: false,
            onRefresh: () async {},
            onManualSetup: () {},
            onSubmit: onSubmit,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
