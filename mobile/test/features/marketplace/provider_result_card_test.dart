import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart'
    show ProviderDayStatus;
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/app_text_scale.dart';

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
    String? dayLabel,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      1.3,
    ).scale(1);
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
                dayLabel: dayLabel,
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

    // Changed on purpose (UX critique, explore.png): the age's words hold
    // together, so «الشهر» never falls to a line of its own.
    expect(find.text('450,000 ر.ي · محدّث هذا الشهر'), findsOneWidget);
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

  // D131: the plan's wedding day, said on the row only with proof.
  testWidgets('a row says the wedding day only when he is known not to take '
      'it, never that he is free', (tester) async {
    final day = DateTime(2027, 1, 21);
    expect(providerDayLabel(day, ProviderDayStatus.full), 'محجوز يوم 21');
    expect(
      providerDayLabel(day, ProviderDayStatus.closed),
      'لا يستقبل حجوزات يوم 21',
    );
    expect(providerDayLabel(day, null), isNull, reason: 'nothing known');
    expect(providerDayLabel(null, ProviderDayStatus.full), isNull);

    await pumpCard(
      tester,
      isClaimed: true,
      dayLabel: providerDayLabel(day, ProviderDayStatus.full),
    );
    expect(find.text('محجوز يوم 21'), findsOneWidget);
    expect(find.byKey(const Key('provider-card-day')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpCard(
      tester,
      isClaimed: true,
      dayLabel: providerDayLabel(day, null),
    );
    await tester.pump();
    expect(find.byKey(const Key('provider-card-day')), findsNothing);
  });

  testWidgets('with no day asked the row says nothing about days', (
    tester,
  ) async {
    await pumpCard(tester, isClaimed: true);
    expect(find.byKey(const Key('provider-card-day')), findsNothing);
  });

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
        find.text('هذا المزود دفع عشان يطلع أول. مش ترشيح من اعّرست.'),
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
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        textScale,
      ).scale(1);
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

    // Changed on purpose (Rashad 2026-11-19, «شكل الكروت سيء»): a provider
    // is a row. The photo is a square at its start, as tall as three lines
    // of words, never a strip and never half the screen.
    testWidgets('the photo is a square at the row start', (tester) async {
      for (final width in [320.0, 360.0, 420.0]) {
        await pumpAt(
          tester,
          width: width,
          imageUrl: 'https://media.example/provider-cover/a.jpg',
        );
        final card = tester.getRect(find.byKey(const Key('card')));
        final photo = tester.getRect(
          find.byKey(const Key('provider-card-photo')),
        );
        expect(photo.width, photo.height, reason: 'at $width');
        expect(photo.width, AarastV3Size.markHero, reason: 'at $width');
        // RTL: the row starts at the right.
        expect(photo.right, greaterThan(card.center.dx), reason: 'at $width');
        expect(card.height, lessThan(card.width * 0.6), reason: 'at $width');
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
          find.text('1,000,000 ر.ي · محدّث هذا الشهر'),
          findsOneWidget,
          reason: 'at $width × $scale',
        );
        expect(tester.takeException(), isNull);
      }
    });

    // Rashad 2026-11-17: without a photo a quarter of every card was a
    // tinted band holding one letter. Without a photo or a logo the letter
    // fills the row's small square, the same square a photo takes.
    testWidgets('without a photo: the letter in the row square', (
      tester,
    ) async {
      await pumpAt(tester, width: 360);
      expect(find.byKey(const Key('provider-card-photo')), findsNothing);
      final letter = tester.getSize(
        find.byKey(const Key('provider-card-letter')),
      );
      expect(letter.width, AarastV3Size.markHero);
      expect(letter.height, AarastV3Size.markHero);
      // «الفنان علي عنبه» is «ف», not the «ا» of the article.
      expect(providerInitial('الفنان علي عنبه'), 'ف');
      expect(providerInitial('استوديو ضوء'), 'ا');
      expect(providerInitial('قاعة سبأ'), 'ق');
    });

    // Rashad's phone 2026-11-18: a logo stretched over the card's top was a
    // face cut at the mouth. A logo alone fills the row's square whole, the
    // same size as a photo, so a row without a cover is not lesser.
    testWidgets('a logo alone takes the row square', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ProviderResultCard(
                key: const Key('card'),
                businessName: 'الفنان علي عنبه',
                isFeatured: false,
                ratingAverage: 1,
                ratingCount: 1,
                isFavorite: false,
                onFavorite: () {},
                onDetails: () {},
                logoUrl: 'https://media.example/provider-logo/a.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('provider-card-photo')), findsNothing);
      final logo = tester.getSize(find.byKey(const Key('provider-card-logo')));
      expect(logo.width, logo.height);
      expect(logo.width, AarastV3Size.markHero);
      expect(tester.takeException(), isNull);
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
