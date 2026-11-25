import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_package_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../support/app_route_table.dart';

// Opened by a link (nothing behind it), back still leaves: to «ملفي».

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  ProviderDashboardProfile? profile,
  List<MarketplaceService> services = const [],
  _Dashboard? dashboard,
}) async {
  final client = ApiClient(tokenProvider: () async => null);
  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(path: '/add', builder: (_, _) => screen),
      GoRoute(
        path: appRoute('/provider/dashboard'),
        builder: (_, state) => Text('opened ${state.uri}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderMarketplaceProvider>(
          create: (_) => _Marketplace(client),
        ),
        ChangeNotifierProvider<ProviderDashboardProvider>(
          create: (_) => dashboard ?? _Dashboard(client, profile, services),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, screen) in [
    ('a new service', const AddProviderServiceScreen()),
    ('a new package', const AddProviderPackageScreen()),
  ]) {
    testWidgets('back leaves $name opened with nothing behind it', (
      tester,
    ) async {
      await _pump(tester, screen);
      // The other provider pages' header: the round back at the title.
      expect(find.byType(JourneySubHeader), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع').first);
      await tester.pumpAndSettle();
      expect(
        find.text('opened /provider/dashboard?tab=profile'),
        findsOneWidget,
      );
    });
  }

  // RA-TS-24: these two were a read of the screens' source for
  // `currencyLabelAr(defaultCurrencyCode)` and `currency: defaultCurrencyCode`.
  // The form is filled and sent, and what it hands over is what is checked.
  const approved = ProviderDashboardProfile(
    id: 'provider-1',
    businessName: 'استوديو ضوء',
    status: 'ACTIVE',
    ratingAverage: 0,
    ratingCount: 0,
    primaryCategoryId: 'cat-photo',
  );

  testWidgets('a new service is priced in rials and sent in YER', (
    tester,
  ) async {
    final dashboard = _Dashboard(
      ApiClient(tokenProvider: () async => null),
      approved,
      const [],
    );
    await _pump(tester, const AddProviderServiceScreen(), dashboard: dashboard);
    expect(find.text('ر.ي'), findsOneWidget);
    expect(find.text('ر.س'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'تصوير الزفة');
    await tester.tap(find.text('القسم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تصوير').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '150000');
    await tester.tap(find.text('إضافة الخدمة'));
    await tester.pumpAndSettle();

    expect(dashboard.created, [
      {
        'kind': 'service',
        'title': 'تصوير الزفة',
        'categoryId': 'cat-photo',
        'basePrice': '150000',
        'currency': 'YER',
      },
    ]);
  });

  testWidgets('a new package is priced in rials and sent in YER', (
    tester,
  ) async {
    final dashboard = _Dashboard(
      ApiClient(tokenProvider: () async => null),
      approved,
      const [],
    );
    await _pump(tester, const AddProviderPackageScreen(), dashboard: dashboard);
    expect(find.text('ر.ي'), findsOneWidget);
    expect(find.text('ر.س'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'باقة الذهب');
    await tester.enterText(find.byType(TextField).at(1), '250000');
    await tester.tap(find.text('إضافة الباقة'));
    await tester.pumpAndSettle();

    expect(dashboard.created, [
      {
        'kind': 'package',
        'title': 'باقة الذهب',
        'price': '250000',
        'currency': 'YER',
      },
    ]);
  });

  // RA-BE-152: after approval a new service goes only in a section his
  // listing already shows in (his category, or an active service's); a new
  // section comes with a category change the team approves.
  testWidgets('an approved provider picks a section his listing is in', (
    tester,
  ) async {
    await _pump(
      tester,
      const AddProviderServiceScreen(),
      profile: const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استوديو ضوء',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
        primaryCategoryId: 'cat-photo',
      ),
      services: const [
        MarketplaceService(
          id: 'service-1',
          providerId: 'provider-1',
          title: 'فيلم الزفة',
          isActive: true,
          categoryId: 'cat-video',
        ),
      ],
    );
    final field = tester.widget<JourneyChoiceField<String>>(
      find.byType(JourneyChoiceField<String>).first,
    );
    // The portal's one word for it.
    expect(field.label, 'القسم');
    expect(
      [for (final choice in field.choices) choice.label],
      ['تصوير', 'فيديو'],
    );
  });
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(ApiClient client) : super(MarketplaceApi(client));

  @override
  Future<void> loadReferenceData() async {}

  @override
  List<ProviderCategory> get categories => const [
    ProviderCategory(id: 'cat-photo', nameAr: 'تصوير'),
    ProviderCategory(id: 'cat-video', nameAr: 'فيديو'),
    ProviderCategory(id: 'cat-hall', nameAr: 'قاعات'),
  ];
}

class _Dashboard extends ProviderDashboardProvider {
  _Dashboard(ApiClient client, this.profile, this.services)
    : super(ProviderDashboardApi(client));

  /// What the form handed to the provider, as `createService` and
  /// `createPackage` were called.
  final created = <Map<String, Object?>>[];

  @override
  Future<bool> createService({
    required String title,
    required String categoryId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    created.add({
      'kind': 'service',
      'title': title,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'currency': currency,
    });
    return true;
  }

  @override
  Future<bool> createPackage({
    required String title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    created.add({
      'kind': 'package',
      'title': title,
      'price': price,
      'currency': currency,
    });
    return true;
  }

  @override
  final ProviderDashboardProfile? profile;

  @override
  final List<MarketplaceService> services;

  @override
  Future<void> loadDashboard() async {}
}
