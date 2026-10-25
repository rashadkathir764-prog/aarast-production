import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/plan_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// w34 «الحجوزات»: booked, waiting, declined and cancelled, each with its
// next step.

final _now = DateTime(2026, 10, 16, 12);

QuoteRequest _quote(
  String id,
  String provider,
  String category,
  Map<String, Object?> booking, {
  String status = 'ACCEPTED',
}) => QuoteRequest(
  id: id,
  providerId: 'provider-$id',
  weddingPlanId: 'plan-1',
  status: status,
  lifecycleStatus: status,
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
    category: ProviderCategory(id: 'cat-$id', nameAr: category),    isActive: true,
  ),
  booking: MarketplaceBooking.fromJson({
    'id': 'booking-$id',
    'quoteRequestId': id,
    'providerId': 'provider-$id',
    'eventDate': '2027-01-21',
    ...booking,
  }),
);

final _quotes = [
  _quote('cancel', 'عدسة سبأ', 'التصوير', {
    'status': 'CANCELLED',
    'cancelledBy': 'CUSTOMER',
    'cancelledAt': '2026-10-15T09:00:00.000',
  }),
  _quote('band', 'الفنان أيمن القاضي', 'الفنان والفرقة', {
    'status': 'DECLINED',
    'note': 'مشغول ذاك اليوم',
    'declinedAt': '2026-10-15T09:00:00.000',
  }),
  _quote('qat', 'مقوّت الروضة', 'القات', {
    'status': 'REQUESTED',
    'createdAt': '2026-10-15T09:00:00.000',
  }),
  _quote('hall', 'قاعة سبأ', 'القاعة', {
    'status': 'CONFIRMED',
    'confirmedAt': '2026-10-15T09:00:00.000',
  }),
];

Future<(_Marketplace, List<Object?>)> _pump(
  WidgetTester tester, {
  List<QuoteRequest>? quotes,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
  addTearDown(tester.view.reset);
  final marketplace = _Marketplace(quotes ?? _quotes);
  final popped = <Object?>[];
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                popped.add(await context.push<String>('/bookings')),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (_, _) =>
            PlanBookingsScreen(weddingPlanId: 'plan-1', now: _now),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Text('opened ${state.uri}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
      value: marketplace,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (marketplace, popped);
}

void main() {
  testWidgets('lists every booking state in the design order', (tester) async {
    await _pump(tester);

    expect(find.text('الحجوزات'), findsOneWidget);
    expect(find.text('محجوز'), findsOneWidget);
    expect(
      find.text('أكدوا 15 أكتوبر · نذكّركم قبل بأسبوع وبيوم'),
      findsOneWidget,
    );
    expect(find.text('ينتظر تأكيدهم'), findsOneWidget);
    expect(find.text('طلبت أمس'), findsOneWidget);
    expect(find.text('اعتذر المزود'), findsOneWidget);
    expect(find.text('اعتذر: مشغول ذاك اليوم'), findsOneWidget);
    expect(find.text('ملغي'), findsOneWidget);
    expect(find.text('لغيته أنت أمس'), findsOneWidget);
    // «ذكّرهم» is dropped: the provider has nothing to receive it.
    expect(find.text('ذكّرهم'), findsNothing);

    final order = [
      'قاعة سبأ',
      'مقوّت الروضة',
      'الفنان أيمن القاضي',
      'عدسة سبأ',
    ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
    expect(order, [...order]..sort());
  });

  testWidgets('a declined booking goes back to find others of its kind', (
    tester,
  ) async {
    final (_, popped) = await _pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('booking-find-others-booking-band')),
    );
    await tester.pumpAndSettle();

    expect(popped, ['الفنان والفرقة']);
  });

  testWidgets('a cancelled booking can be asked for again', (tester) async {
    final (marketplace, _) = await _pump(tester);

    await tester.tap(find.text('اطلب حجز مرة ثانية'));
    await tester.pumpAndSettle();

    expect(marketplace.asked, ['cancel']);
  });

  testWidgets('a booking whose day passed asks for a rating', (tester) async {
    await _pump(
      tester,
      quotes: [
        _quote('studio', 'استوديو ضوء صنعاء', 'التصوير', {
          'status': 'CONFIRMED',
          'lifecycleStatus': 'COMPLETED',
        }),
      ],
    );

    expect(find.text('تمّ'), findsOneWidget);
    await tester.tap(find.text('قيّمهم'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'opened /wedding-plans/plan-1/providers/reviews?provider=provider-studio',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a plan with no bookings says so', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: _Marketplace(const []),
        child: MaterialApp(
          home: PlanBookingsScreen(weddingPlanId: 'plan-1', now: _now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما حجزت عند أحد بعد'), findsOneWidget);
  });
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(this._quotes)
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> _quotes;
  final asked = <String>[];

  @override
  List<QuoteRequest> get quoteRequests => _quotes;

  @override
  bool get isSubmitting => false;

  @override
  Future<void> loadScopedQuoteRequests() async {}

  @override
  Future<bool> requestBooking(QuoteRequest quote, {DateTime? eventDate}) async {
    asked.add(quote.id);
    return true;
  }
}
