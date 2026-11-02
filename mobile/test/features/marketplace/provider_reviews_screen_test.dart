import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// g04 rating the providers after the day, x12 the thanks, w35 the lock
// before the day.

QuoteRequest _booked(
  String id,
  String provider,
  String category,
  String lifecycle,
) => QuoteRequest(
  id: 'quote-$id',
  providerId: 'provider-$id',
  weddingPlanId: 'plan-1',
  status: 'ACCEPTED',
  lifecycleStatus: 'ACCEPTED',
  provider: ProviderSummary(
    id: 'provider-$id',
    businessName: provider,
    ratingAverage: 0,
    ratingCount: 0,
  ),
  service: MarketplaceService(
    id: 'service-$id',
    providerId: 'provider-$id',
    title: category,
    category: ProviderCategory(id: 'cat-$id', nameAr: category),
    isActive: true,
  ),
  booking: MarketplaceBooking.fromJson({
    'id': 'booking-$id',
    'quoteRequestId': 'quote-$id',
    'providerId': 'provider-$id',
    'eventDate': '2027-01-21',
    'status': 'CONFIRMED',
    'lifecycleStatus': lifecycle,
  }),
);

Future<_Marketplace> _pump(
  WidgetTester tester,
  List<QuoteRequest> quotes, {
  Map<String, List<ProviderReview>> reviews = const {},
  String? providerId,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1200);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final marketplace = _Marketplace(quotes);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
        ),
        Provider<MarketplaceApi>.value(value: _Api(reviews)),
        ChangeNotifierProvider<AuthController>.value(value: _Auth(storage)),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: ProviderReviewsScreen(
          weddingPlanId: 'plan-1',
          providerId: providerId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return marketplace;
}

void main() {
  testWidgets('g04 rates the next provider, then x12 thanks and moves on', (
    tester,
  ) async {
    final marketplace = await _pump(tester, [
      _booked('studio', 'استوديو ضوء صنعاء', 'التصوير', 'COMPLETED'),
      _booked('hall', 'قاعة سبأ', 'القاعة', 'COMPLETED'),
    ]);

    expect(find.text('قيّم مزودينك'), findsOneWidget);
    expect(find.text('0 من 2 · تقييمك يساعد العرسان الجايين'), findsOneWidget);
    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
    // The server shows the account's name as it is, not a first name.
    expect(find.text('يطلع باسمك: محمد'), findsOneWidget);
    // No quick tags: nothing keeps them.
    expect(find.text('ايش عجبك؟'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reviews-star-4')));
    await tester.pump();
    expect(find.text('ممتاز'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'الفيلم وصل بعد أسبوعين بالضبط',
    );
    await tester.tap(find.text('أرسل التقييم والتالي'));
    await tester.pumpAndSettle();

    expect(marketplace.sent, [
      'provider-studio:4:الفيلم وصل بعد أسبوعين بالضبط',
    ]);
    expect(find.text('تقييمك'), findsOneWidget);
    expect(find.text('وصل تقييمك عن استوديو ضوء صنعاء'), findsOneWidget);
    expect(find.text('انشر الآن'), findsOneWidget);
    expect(find.text('باقي تقيّم'), findsOneWidget);

    await tester.tap(find.text('قيّم قاعة سبأ'));
    await tester.pumpAndSettle();
    expect(find.text('1 من 2 · تقييمك يساعد العرسان الجايين'), findsOneWidget);
    expect(find.text('قيّمتهم'), findsOneWidget);
    expect(find.text('أرسل التقييم'), findsOneWidget);
  });

  testWidgets('a provider rated before is not asked again', (tester) async {
    await _pump(
      tester,
      [
        _booked('studio', 'استوديو ضوء صنعاء', 'التصوير', 'COMPLETED'),
        _booked('hall', 'قاعة سبأ', 'القاعة', 'COMPLETED'),
      ],
      reviews: {
        'provider-hall': [
          ProviderReview.fromJson({
            'id': 'review-1',
            'userId': 'user-1',
            'rating': 5,
          }),
        ],
        'provider-studio': [
          ProviderReview.fromJson({
            'id': 'review-2',
            'userId': 'someone-else',
            'rating': 2,
          }),
        ],
      },
      providerId: 'provider-hall',
    );

    // The hall was rated by this account; the studio was not.
    expect(find.text('1 من 2 · تقييمك يساعد العرسان الجايين'), findsOneWidget);
    expect(find.text('قيّمتهم'), findsOneWidget);
    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
  });

  testWidgets('w35 a provider whose day is ahead cannot be rated yet', (
    tester,
  ) async {
    await _pump(tester, [
      _booked('hall', 'قاعة سبأ', 'القاعة', 'CONFIRMED'),
    ], providerId: 'provider-hall');

    expect(find.text('قاعة سبأ'), findsOneWidget);
    expect(find.text('التقييم بعد العرس'), findsOneWidget);
    expect(
      find.text(
        'تقيّم المزود بعد يوم الحجز بس، عشان كل تقييم يكون من تجربة حقيقية.',
      ),
      findsOneWidget,
    );
    expect(find.text('التقييم يطلع باسمك: محمد.'), findsOneWidget);
    // No reminder is scheduled, so none is promised.
    expect(find.textContaining('نذكّرك'), findsNothing);
  });
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(this._quotes)
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> _quotes;
  final sent = <String>[];

  @override
  List<QuoteRequest> get quoteRequests => _quotes;

  @override
  Future<void> loadScopedQuoteRequests() async {}

  @override
  Future<String?> reviewProvider({
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    sent.add('$providerId:$rating:${comment ?? ''}');
    return null;
  }
}

class _Api extends MarketplaceApi {
  _Api(this._reviews) : super(ApiClient(tokenProvider: () async => null));

  final Map<String, List<ProviderReview>> _reviews;

  @override
  Future<List<ProviderReview>> getProviderReviews(String providerId) async =>
      _reviews[providerId] ?? const [];
}

class _Auth extends AuthController {
  _Auth(AuthStorage storage)
    : super(
        AuthRepository(
          ApiClient(tokenProvider: storage.readAccessToken),
          storage,
        ),
      );

  @override
  SafeUser? get user => const SafeUser(
    id: 'user-1',
    name: 'محمد',
    role: 'USER',
    status: 'ACTIVE',
  );
}
