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
          create: (_) => _Dashboard(client, profile, services),
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
      await tester.tap(find.byTooltip('رجوع').first);
      await tester.pumpAndSettle();
      expect(
        find.text('opened /provider/dashboard?tab=profile'),
        findsOneWidget,
      );
    });
  }

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
    expect(field.label, 'الفئة');
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

  @override
  final ProviderDashboardProfile? profile;

  @override
  final List<MarketplaceService> services;

  @override
  Future<void> loadDashboard() async {}
}
