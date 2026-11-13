import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/plan_bookings_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RA-MO-244 (batch 7): «الحجوزات» and «قيّم مزودينك» read the plan's
// requests without saying which plan. The requests list answers «nothing»
// until some page names the plan, and only the providers tab, a provider's
// page and the money overview did. Opened first (from the home card, a
// notification, a link), both pages said the plan had no bookings.

final _booked = QuoteRequest(
  id: 'quote-1',
  providerId: 'provider-1',
  weddingPlanId: 'plan-1',
  status: 'ACCEPTED',
  lifecycleStatus: 'ACCEPTED',
  provider: const ProviderSummary(
    id: 'provider-1',
    businessName: 'قاعة سبأ',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  service: const MarketplaceService(
    id: 'service-1',
    providerId: 'provider-1',
    title: 'القاعة',
    category: ProviderCategory(id: 'cat-1', nameAr: 'القاعة'),
    isActive: true,
  ),
  booking: MarketplaceBooking.fromJson(const {
    'id': 'booking-1',
    'quoteRequestId': 'quote-1',
    'providerId': 'provider-1',
    'eventDate': '2026-09-01',
    'status': 'CONFIRMED',
    'lifecycleStatus': 'COMPLETED',
  }),
);

Future<_Api> _pump(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  final api = _Api();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        // The app's own list, as it is before any page named a plan.
        ChangeNotifierProvider<ProviderMarketplaceProvider>(
          create: (_) => ProviderMarketplaceProvider(api),
        ),
        Provider<MarketplaceApi>.value(value: api),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('«الحجوزات» opened first reads its own plan\'s bookings', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      PlanBookingsScreen(
        weddingPlanId: 'plan-1',
        now: DateTime(2026, 10, 16, 12),
      ),
    );

    expect(api.askedPlans, ['plan-1']);
    expect(find.text('قاعة سبأ'), findsOneWidget);
  });

  testWidgets('«قيّم مزودينك» opened first reads its own plan\'s bookings', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      const ProviderReviewsScreen(weddingPlanId: 'plan-1'),
    );

    expect(api.askedPlans, ['plan-1']);
    expect(find.textContaining('قاعة سبأ'), findsWidgets);
  });
}

class _Api extends MarketplaceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final askedPlans = <String>[];

  @override
  Future<List<QuoteRequest>> cachedPlanQuoteRequests(
    String weddingPlanId,
  ) async => const [];

  @override
  Future<List<QuoteRequest>> getPlanQuoteRequests(String weddingPlanId) async {
    askedPlans.add(weddingPlanId);
    return weddingPlanId == 'plan-1' ? [_booked] : const [];
  }

  @override
  Future<List<ProviderReview>> getProviderReviews(String providerId) async =>
      const [];
}
