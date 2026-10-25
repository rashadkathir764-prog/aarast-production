import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/booking_moment_ledger.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/booking_moment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// y09: the provider confirmed the booking.

final _band = QuoteRequest(
  id: 'quote-band',
  providerId: 'provider-band',
  weddingPlanId: 'plan-1',
  status: 'ACCEPTED',
  lifecycleStatus: 'ACCEPTED',
  message: 'الفترة: الليل · بعد المغرب\nنشتي الزفة كاملة',
  provider: const ProviderSummary(
    id: 'provider-band',
    businessName: 'فرقة الأفراح',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  service: const MarketplaceService(
    id: 'service-band',
    providerId: 'provider-band',
    title: 'الزفة',
    category: ProviderCategory(id: 'cat-band', nameAr: 'الفنان والفرقة'),    isActive: true,
  ),
  offers: const [
    QuoteOffer(
      id: 'offer-band',
      status: 'ACCEPTED',
      amount: '400000',
      currency: 'YER',
    ),
  ],
  booking: MarketplaceBooking.fromJson({
    'id': 'booking-band',
    'quoteRequestId': 'quote-band',
    'quoteOfferId': 'offer-band',
    'providerId': 'provider-band',
    'eventDate': '2027-01-21',
    'status': 'CONFIRMED',
  }),
);

Future<List<String>> _pump(
  WidgetTester tester, {
  FinanceProvider? finance,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 860);
  addTearDown(tester.view.reset);
  final opened = <String>[];
  final router = GoRouter(
    initialLocation: '/moment',
    routes: [
      GoRoute(
        path: '/moment',
        builder: (_, _) => const BookingMomentScreen(
          weddingPlanId: 'plan-1',
          quoteId: 'quote-band',
        ),
      ),
    ],
    errorBuilder: (context, state) {
      opened.add(state.uri.toString());
      return const SizedBox.shrink();
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: _Marketplace([_band]),
        ),
        if (finance != null)
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('the first look remembers old bookings; a new one is unseen', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = BookingMomentLedger(await SharedPreferences.getInstance());

    expect(await ledger.unseen('plan-1', ['old']), isEmpty);
    expect(await ledger.unseen('plan-1', ['old', 'new']), ['new']);
    await ledger.markSeen('plan-1', 'new');
    expect(await ledger.unseen('plan-1', ['old', 'new']), isEmpty);
    // Another plan starts its own record.
    expect(await ledger.unseen('plan-2', ['other']), isEmpty);
  });

  testWidgets('says who booked the night and what it costs', (tester) async {
    await _pump(tester);

    expect(find.text('طلب الحجز انقبل'), findsOneWidget);
    expect(find.text('ليلتك محجوزة\nعند فرقة الأفراح'), findsOneWidget);
    expect(find.text('الخميس 21 يناير · بعد المغرب'), findsOneWidget);
    expect(find.text('الفنان والفرقة'), findsOneWidget);
    expect(find.text('400,000 ر.ي'), findsOneWidget);
    // No needed-providers list exists to count «4 من 6» against (C25).
    expect(find.textContaining('من 6'), findsNothing);
    // Without a cost to pay into, the moment just closes.
    expect(find.text('تمام'), findsOneWidget);
  });

  testWidgets('with the deposit scheduled, it records that payment', (
    tester,
  ) async {
    final finance = FinanceProvider(_Finance());
    await finance.loadMoney('plan-1');

    final opened = await _pump(tester, finance: finance);

    expect(find.text('العربون'), findsOneWidget);
    expect(find.text('100,000 ر.ي · 14 يناير'), findsOneWidget);
    await tester.tap(find.text('سجّل العربون'));
    await tester.pumpAndSettle();

    expect(opened, [
      '/wedding-plans/plan-1/money/costs/cost-band/schedules/schedule-1/pay',
    ]);
  });
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(this._quotes)
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> _quotes;

  @override
  List<QuoteRequest> get quoteRequests => _quotes;
}

class _Finance extends FinanceApi {
  _Finance() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async =>
      const MoneySummary(planId: 'plan-1', categories: []);

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
    String? payer,
  }) async => const FinancePage(
    items: [
      WeddingCost(
        id: 'cost-band',
        weddingPlanId: 'plan-1',
        budgetCategoryId: 'band',
        title: 'الزفة',
        totalAmount: '400000',
        paidAmount: '0',
        remainingAmount: '400000',
        status: 'OPEN',
        providerId: 'provider-band',
        quoteOfferId: 'offer-band',
      ),
    ],
    page: 1,
    pageSize: 30,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async => [
    PaymentSchedule(
      id: 'schedule-1',
      costId: 'cost-band',
      amount: '100000',
      dueDate: DateTime(2027, 1, 14),
      status: 'PENDING',
      note: 'العربون',
    ),
  ];
}
