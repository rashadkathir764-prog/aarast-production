import 'dart:math' as math;

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/l10n/aarast_text.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import '../../support/app_text_scale.dart';
import '../../support/preview_fonts.dart';

// Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7, the final providers
// proposal): the card is one row anatomy built from the server's row
// (ProviderRow over providerCardFacts), so these tests give it a provider,
// not loose labels. What changed and why:
// - the picture is 4:3, 120 wide, not a 72 square: the work photo is the
//   one bold thing of the screen;
// - the line under the name is the city alone (with the category he was
//   found under when it is not his), not «القاعات · صنعاء»;
// - with no review: «جديد» only in a listing's first 30 days, else «لا
//   تقييمات بعد» (it used to be «جديد» forever);
// - the day's status is «مغلق يوم عرسك» / «محجوز يوم عرسك», a line with its
//   mark, not «محجوز يوم 21» in a tag;
// - an unclaimed listing's line is «لا يستقبل طلبات العروض بعد».
//
// Changed again on purpose (2026-11-26, the merge of the two proposals,
// docs/project/refinement/COMPARISON.md «صف القائمة»): the picture is 112
// wide (4:3, 84 tall), and the heart left the picture for the row's end, as
// in the first proposal: on a 4:3 thumbnail it crowded the photo. The row
// pins both: the picture at the start, the heart at the end in 48.

const _halls = ProviderCategory(
  id: 'cat-halls',
  nameAr: 'صالة',
  slug: 'wedding-halls',
);
const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
final _now = DateTime(2026, 10, 26, 12);
final _day = DateTime(2027, 1, 21);

MarketplaceProvider _provider({
  String name = 'قاعة السعادة للأفراح',
  bool claimed = true,
  bool verified = false,
  bool featured = false,
  String? minPrice,
  ProviderDayStatus? day,
  int reviews = 63,
  DateTime? created,
  String? photo,
  String? logo,
}) => MarketplaceProvider(
  id: 'p1',
  businessName: name,
  ownerName: '',
  ratingAverage: reviews == 0 ? 0 : 4.8,
  ratingCount: reviews,
  primaryCategory: _halls,
  primaryCategoryId: _halls.id,
  city: _sanaa,
  isClaimed: claimed,
  verifiedAt: verified ? DateTime(2026) : null,
  featuredUntil: featured ? DateTime(2030) : null,
  dayStatus: day,
  createdAt: created ?? DateTime(2025),
  cardPhotoUrl: photo,
  logoUrl: logo,
  serviceSummary: MarketplaceProviderServiceSummary(
    activeCount: 1,
    minPrice: minPrice,
    maxPrice: minPrice,
    currency: minPrice == null ? null : 'YER',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  MarketplaceProvider provider, {
  double width = 320,
  double textScale = 1.3,
  DateTime? askedDay,
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
            child: Builder(
              builder: (context) => ProviderRow(
                key: const Key('card'),
                facts: providerCardFacts(
                  provider,
                  bridePlan: false,
                  now: _now,
                  askedDay: askedDay,
                ),
                isFavorite: false,
                onFavorite: () {},
                onOpen: () {},
                minHeight: providerRowHeight(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // The room a figure takes is the app's font's, not the test font's
  // one-em boxes: with the heart at the row's end (the merge) a price at 320
  // and 1.3 is judged by the glyphs the phone draws.
  setUpAll(loadPreviewAppFonts);

  testWidgets('f02 a verified provider: its facts in the card order', (
    tester,
  ) async {
    await _pump(tester, _provider(verified: true, minPrice: '450000'));
    final price = aarastText.providersPriceFrom('450 ألفًا');
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.byKey(const Key('provider-rating')), findsOneWidget);
    expect(find.text(price), findsOneWidget);
    expect(find.byKey(const Key('provider-card-verified')), findsOneWidget);
    expect(find.byKey(const Key('provider-card-status')), findsNothing);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(find.text('صنعاء')),
      lessThan(top(find.byKey(const Key('provider-rating')))),
    );
    expect(
      top(find.byKey(const Key('provider-rating'))),
      lessThan(top(find.text(price))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no review: «جديد» in the first 30 days, «لا تقييمات بعد» '
      'after, never empty stars', (tester) async {
    await _pump(tester, _provider(reviews: 0, created: DateTime(2026, 10, 1)));
    expect(find.text(aarastText.providersNew), findsOneWidget);
    expect(find.byKey(const Key('provider-rating')), findsNothing);
    await _pump(tester, _provider(reviews: 0, created: DateTime(2026, 6, 1)));
    expect(find.text(aarastText.providersNoReviews), findsOneWidget);
    expect(find.text(aarastText.providersNew), findsNothing);
  });

  testWidgets('w33 an unclaimed listing says it takes no requests, even '
      'with a price', (tester) async {
    await _pump(tester, _provider(claimed: false, minPrice: '450000'));
    expect(find.text(aarastText.providersUnclaimedLine), findsOneWidget);
    // A listing nobody answers for is never «موثّق».
    expect(find.byKey(const Key('provider-card-verified')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unclaimed listing without a price says no price at all', (
    tester,
  ) async {
    await _pump(tester, _provider(claimed: false));
    expect(find.text(aarastText.providersPriceOnRequest), findsNothing);
    expect(find.text(aarastText.providersUnclaimedLine), findsOneWidget);
  });

  // D131: the plan's wedding day, said on the row only with proof.
  testWidgets('a row says the wedding day only when he is known not to take '
      'it, never that he is free', (tester) async {
    expect(
      providerDayLine(_day, ProviderDayStatus.full, now: _now),
      aarastText.providersDayFull,
    );
    expect(
      providerDayLine(_day, ProviderDayStatus.closed, now: _now),
      aarastText.providersDayClosed,
    );
    expect(providerDayLine(_day, null, now: _now), isNull);
    expect(providerDayLine(null, ProviderDayStatus.full, now: _now), isNull);

    await _pump(tester, _provider(day: ProviderDayStatus.full), askedDay: _day);
    expect(find.text(aarastText.providersDayFull), findsOneWidget);
    expect(find.byKey(const Key('provider-card-status')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(tester, _provider(), askedDay: _day);
    expect(find.byKey(const Key('provider-card-status')), findsNothing);
  });

  // One rule with his page (`priceFitsItem`): the row said «ضمن بندك» of a
  // price up to a fifth OVER the item, and «أقل من بندك» of a provider whose
  // page said «ضمن بندك».
  test('«ضمن بندك» is a price that does not pass the item, on the row as on '
      'his page', () {
    String? status(String price) => providerCardFacts(
      _provider(minPrice: price),
      bridePlan: false,
      now: _now,
      budget: const ProviderBudgetMatchIntent(
        budgetCategoryName: 'القاعة',
        allocatedAmount: '1000000',
      ),
    ).status?.text;

    expect(status('500000'), aarastText.providersBudgetWithin);
    expect(status('1000000'), aarastText.providersBudgetWithin);
    // Ten percent over the item is over it.
    expect(status('1100000'), aarastText.providersBudgetAbove);
    expect(priceFitsItem(1000000, 1000000), isTrue);
    expect(priceFitsItem(1000001, 1000000), isFalse);
    // An item with no amount fits nothing: nothing is said.
    expect(priceFitsItem(100, 0), isFalse);
  });

  // The real app (bride walk, 2026-11-28): the hall she booked herself read
  // «محجوز يوم عرسك» in the danger's colour, as if someone else took it. The
  // day's count holds her own booking.
  test('a provider the reader booked for the day is said as theirs', () {
    ProviderStatusLine? status({required bool mine, DateTime? day}) =>
        providerCardFacts(
          _provider(day: ProviderDayStatus.full),
          bridePlan: true,
          now: _now,
          askedDay: day ?? _day,
          bookedByReader: mine,
        ).status;

    expect(status(mine: true)!.text, aarastText.providersDayYours);
    expect(status(mine: true)!.color, AarastV3Color.mint);
    expect(status(mine: false)!.text, aarastText.providersDayFull);
    expect(status(mine: false)!.color, AarastV3Color.danger);
    // A day already past says nothing of the calendar, theirs or not.
    final past = _now.subtract(const Duration(days: 3));
    expect(status(mine: true, day: past), isNull);
  });

  testWidgets('a claimed provider without a price: «السعر عند الطلب»', (
    tester,
  ) async {
    await _pump(tester, _provider());
    expect(find.text(aarastText.providersPriceOnRequest), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B-43 «مميز» on the picture says, when tapped, that he paid', (
    tester,
  ) async {
    await _pump(tester, _provider(featured: true), textScale: 1);
    expect(find.text(aarastText.providersFeatured), findsOneWidget);
    await tester.tap(find.byKey(const Key('provider-card-featured')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider-featured-sheet')), findsOneWidget);
    expect(find.text(aarastText.providersFeaturedWhy), findsOneWidget);
    await tester.tap(find.text(aarastText.providersGotIt));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider-featured-sheet')), findsNothing);
  });

  testWidgets('a provider that is not featured carries no «مميز»', (
    tester,
  ) async {
    await _pump(tester, _provider());
    expect(find.byKey(const Key('provider-card-featured')), findsNothing);
  });

  group('the picture and the room it takes', () {
    testWidgets('4:3 at the row start, 112 wide; the heart at its end', (
      tester,
    ) async {
      for (final width in [320.0, 360.0, 420.0]) {
        await _pump(
          tester,
          _provider(photo: 'https://media.example/work/a.jpg'),
          width: width,
          textScale: 1,
        );
        final card = tester.getRect(find.byKey(const Key('card')));
        final photo = tester.getRect(
          find.byKey(const Key('provider-card-photo')),
        );
        // 112, or 5/16 of the narrowest phone (100 of 320), so a name and
        // a whole price keep their room between it and the heart at the
        // largest text.
        expect(
          photo.width,
          closeTo(math.min(112, width * 0.3125), 0.01),
          reason: 'at $width',
        );
        expect(photo.width / photo.height, closeTo(4 / 3, 0.01));
        // RTL: the row starts at the right, and the heart closes it at the
        // left, off the picture.
        expect(photo.right, greaterThan(card.center.dx), reason: 'at $width');
        final heart = tester.getRect(
          find.bySemanticsLabel(aarastText.providersFavoriteAdd),
        );
        expect(heart.right, lessThan(card.center.dx), reason: 'at $width');
        expect(photo.overlaps(heart), isFalse, reason: 'at $width');
      }
    });

    testWidgets('a photo is fitted from its top, where a face is', (
      tester,
    ) async {
      await _pump(tester, _provider(photo: 'https://media.example/w/a.jpg'));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect((image.alignment as Alignment).y, lessThan(0));
    });

    testWidgets('the price keeps its line whole at 320 and 1.3', (
      tester,
    ) async {
      await _pump(tester, _provider(minPrice: '1850000'));
      final price = find.byKey(const Key('provider-card-price'));
      expect(
        tester.renderObject<RenderParagraph>(price).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a photo or a logo: the initial in the picture', (
      tester,
    ) async {
      await _pump(tester, _provider(name: 'الفنان علي عنبه'));
      expect(find.byKey(const Key('provider-card-photo')), findsNothing);
      final letter = tester.getSize(
        find.byKey(const Key('provider-card-letter')),
      );
      // The picture's own room: 5/16 of the 320 phone.
      expect(letter.width, closeTo(320 * 0.3125, 0.01));
      expect(providerInitial('الفنان علي عنبه'), 'ف');
      expect(providerInitial('استوديو ضوء'), 'ا');
      expect(providerInitial('قاعة سبأ'), 'ق');
    });

    testWidgets('a logo alone sits whole on a quiet tint', (tester) async {
      await _pump(
        tester,
        _provider(logo: 'https://media.example/provider-logo/a.jpg'),
      );
      expect(find.byKey(const Key('provider-card-photo')), findsNothing);
      expect(find.byKey(const Key('provider-card-logo')), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    });

    testWidgets('nothing overflows at 320 with the largest text; the heart '
        'keeps a 48 target', (tester) async {
      await _pump(tester, _provider(minPrice: '12500000'));
      expect(tester.takeException(), isNull);
      final heart = tester.getSize(
        find.bySemanticsLabel(aarastText.providersFavoriteAdd),
      );
      expect(heart.width, greaterThanOrEqualTo(AarastV3Size.touch));
      expect(heart.height, greaterThanOrEqualTo(AarastV3Size.touch));
    });
  });
}
