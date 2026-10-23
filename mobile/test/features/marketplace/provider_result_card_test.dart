import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('w33 how old a published price is', () {
    final now = DateTime(2026, 10, 23);

    test('a price from this month says so', () {
      expect(
        providerPriceAgeLabel(DateTime(2026, 10, 2), now: now),
        'محدّث هذا الشهر',
      );
    });

    test('an older price counts the months', () {
      expect(
        providerPriceAgeLabel(DateTime(2026, 2, 20), now: now),
        'محدّث قبل 8 شهور',
      );
      expect(
        providerPriceAgeLabel(DateTime(2026, 8, 20), now: now),
        'محدّث قبل شهرين',
      );
    });

    test('no date means no claim about its age', () {
      expect(providerPriceAgeLabel(null, now: now), isNull);
    });
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required bool isClaimed,
    bool isVerified = false,
    String? priceLabel,
    String? priceAgeLabel,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProviderResultCard(
                businessName: 'قاعة السعادة للأفراح',
                isFeatured: false,
                ratingAverage: 4.8,
                ratingCount: 63,
                isFavorite: false,
                onFavorite: () {},
                onDetails: () {},
                isClaimed: isClaimed,
                isVerified: isVerified,
                categoryLabel: 'القاعات',
                locationLabel: 'صنعاء',
                priceLabel: priceLabel,
                priceAgeLabel: priceAgeLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('f02 a verified provider shows its price and how old it is', (
    tester,
  ) async {
    await pumpCard(
      tester,
      isClaimed: true,
      isVerified: true,
      priceLabel: '450,000 ر.ي',
      priceAgeLabel: 'محدّث هذا الشهر',
    );

    expect(find.text('450,000 ر.ي · محدّث هذا الشهر'), findsOneWidget);
    expect(find.byKey(const Key('provider-card-verified')), findsOneWidget);
    expect(find.byKey(const Key('provider-card-unclaimed-note')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'w33 an unclaimed listing says it takes no requests, even with a price',
    (tester) async {
      await pumpCard(tester, isClaimed: false, priceLabel: '450,000 ر.ي');

      expect(find.text('450,000 ر.ي'), findsOneWidget);
      expect(find.byKey(const Key('provider-card-unclaimed')), findsOneWidget);
      expect(
        find.byKey(const Key('provider-card-unclaimed-note')),
        findsOneWidget,
      );
      expect(find.text('ما يستقبل طلبات لين يستلم صاحبه ملفه'), findsOneWidget);
      // A listing nobody answers for is never «موثّق».
      expect(find.byKey(const Key('provider-card-verified')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a claimed provider without a price asks for an offer', (
    tester,
  ) async {
    await pumpCard(tester, isClaimed: true);

    expect(find.text('اطلب عرض تعرف السعر'), findsOneWidget);
    expect(find.byKey(const Key('provider-card-unclaimed-note')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
