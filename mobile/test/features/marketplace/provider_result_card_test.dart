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
    bool isFeatured = false,
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
                isFeatured: isFeatured,
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

  testWidgets(
    'B-43 the drawn «مميز» says, when tapped, that he paid and it is no recommendation',
    (tester) async {
      await pumpCard(tester, isClaimed: true, isFeatured: true);

      expect(find.text('مميز'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-card-featured')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('provider-featured-sheet')), findsOneWidget);
      expect(
        find.text('هذا المزود دفع عشان يطلع أول. مو ترشيح من اعّرست.'),
        findsOneWidget,
      );
      await tester.tap(find.text('فهمت'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('provider-featured-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a provider that is not featured carries no «مميز»', (
    tester,
  ) async {
    await pumpCard(tester, isClaimed: true);
    expect(find.byKey(const Key('provider-card-featured')), findsNothing);
    expect(find.text('مميز'), findsNothing);
  });

  // RA-MO-316: the photo filled a strip as wide as the card and 120 high,
  // so a provider's portrait showed a nose and a mouth, and a provider
  // without a photo showed an empty band over a card that was half blank.
  group('the photo and the room it takes', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required double width,
      double textScale = 1,
      String? imageUrl,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
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
                padding: const EdgeInsets.all(16),
                child: ProviderResultCard(
                  key: const Key('card'),
                  businessName: 'الفنان علي عنبه',
                  isFeatured: false,
                  ratingAverage: 4.8,
                  ratingCount: 12,
                  isFavorite: false,
                  onFavorite: () {},
                  onDetails: () {},
                  categoryLabel: 'فنان',
                  locationLabel: 'صنعاء',
                  priceLabel: '1,000,000 ر.ي',
                  priceAgeLabel: 'محدّث هذا الشهر',
                  imageUrl: imageUrl,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // Changed on purpose (Rashad 2026-11-18, «استكشف» made anew): the photo
    // is the card's top, as wide as the card. It is still never a strip:
    // three high for every four wide, over twice RA-MO-316's 120.
    testWidgets('the photo is the card top, never a strip', (tester) async {
      for (final width in [320.0, 360.0, 420.0]) {
        await pumpAt(
          tester,
          width: width,
          imageUrl: 'https://media.example/provider-cover/a.jpg',
        );
        final card = tester.getSize(find.byKey(const Key('card')));
        final photo = tester.getSize(
          find.byKey(const Key('provider-card-photo')),
        );
        expect(photo.width, card.width, reason: 'at $width');
        expect(
          photo.height,
          closeTo(photo.width * 3 / 4, 1),
          reason: 'at $width',
        );
        expect(photo.height, greaterThan(200), reason: 'at $width');
      }
    });

    testWidgets('a photo is fitted from its top, where a face is', (
      tester,
    ) async {
      await pumpAt(
        tester,
        width: 360,
        imageUrl: 'https://media.example/provider-cover/a.jpg',
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect((image.alignment as Alignment).y, lessThan(0));
      expect((image.alignment as Alignment).x, 0);
    });

    // With the photo on top, the words under it take the card's width: the
    // price and its age keep one line, and nothing overflows at 1.3.
    testWidgets('the words under the photo take the card width', (
      tester,
    ) async {
      for (final (width, scale) in [(360.0, 1.0), (320.0, 1.3)]) {
        await pumpAt(
          tester,
          width: width,
          textScale: scale,
          imageUrl: 'https://media.example/provider-cover/a.jpg',
        );
        expect(
          find.text('1,000,000 ر.ي · محدّث هذا الشهر'),
          findsOneWidget,
          reason: 'at $width × $scale',
        );
        expect(tester.takeException(), isNull);
      }
    });

    // Rashad 2026-11-17: without a photo a quarter of every card was a
    // tinted band holding one letter. The letter is a small square now, and
    // the words take the card.
    testWidgets('without a photo: a small letter, not a band', (tester) async {
      await pumpAt(tester, width: 360);
      expect(find.byKey(const Key('provider-card-photo')), findsNothing);
      final letter = tester.getSize(
        find.byKey(const Key('provider-card-letter')),
      );
      final card = tester.getSize(find.byKey(const Key('card')));
      expect(letter.width, lessThanOrEqualTo(48));
      expect(letter.height, lessThan(card.height));
      // «الفنان علي عنبه» is «ف», not the «ا» of the article.
      expect(providerInitial('الفنان علي عنبه'), 'ف');
      expect(providerInitial('استوديو ضوء'), 'ا');
      expect(providerInitial('قاعة سبأ'), 'ق');
    });

    testWidgets('nothing overflows at 320 with the largest text', (
      tester,
    ) async {
      await pumpAt(tester, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
      // The heart keeps a full touch target.
      final heart = tester.getSize(find.bySemanticsLabel('حفظ المزود'));
      expect(heart.width, greaterThanOrEqualTo(48));
      expect(heart.height, greaterThanOrEqualTo(48));
    });
  });
}
