import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_package_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Opened by a link (nothing behind it), back still leaves: to «ملفي».

Future<void> _pump(WidgetTester tester, Widget screen) async {
  final client = ApiClient(tokenProvider: () async => null);
  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(path: '/add', builder: (_, _) => screen),
      GoRoute(
        path: '/provider/dashboard',
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
          create: (_) => _Dashboard(client),
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
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace(ApiClient client) : super(MarketplaceApi(client));

  @override
  Future<void> loadReferenceData() async {}
}

class _Dashboard extends ProviderDashboardProvider {
  _Dashboard(ApiClient client) : super(ProviderDashboardApi(client));

  @override
  Future<void> loadDashboard() async {}
}
