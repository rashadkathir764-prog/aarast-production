import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('popup menus are clean surfaces without the M3 pink tint', () {
    final theme = AppTheme.light();
    final popupTheme = theme.popupMenuTheme;
    expect(popupTheme.surfaceTintColor, Colors.transparent);
    expect(popupTheme.color, AppTheme.surfaceRaised);
  });

  testWidgets('city picker opens as compact pills and applies the choice', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      cities: const [
        MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
        MarketplaceCity(id: 'city-2', nameAr: 'عدن'),
      ],
    );

    await _pump(tester, state);

    await tester.tap(find.byKey(const Key('city-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('كل المدن'), findsOneWidget);
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text('عدن'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('city-pill-city-1')));
    await tester.pumpAndSettle();

    expect(state.setCityCalls, ['city-1']);
    // اللوحة تنغلق بعد الاختيار.
    expect(find.byKey(const ValueKey('city-pill-all')), findsNothing);
  });

  testWidgets('choosing all cities clears the filter', (tester) async {
    final state = _FakeMarketplaceProvider(
      cities: const [MarketplaceCity(id: 'city-1', nameAr: 'صنعاء')],
      cityId: 'city-1',
    );

    await _pump(tester, state);

    await tester.tap(find.byKey(const Key('city-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('city-pill-all')));
    await tester.pumpAndSettle();

    expect(state.setCityCalls, [null]);
  });

  testWidgets('dismissing the picker changes nothing', (tester) async {
    final state = _FakeMarketplaceProvider(
      cities: const [MarketplaceCity(id: 'city-1', nameAr: 'صنعاء')],
    );

    await _pump(tester, state);

    await tester.tap(find.byKey(const Key('city-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(state.setCityCalls, isEmpty);
  });
}

Future<void> _pump(WidgetTester tester, _FakeMarketplaceProvider state) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'test-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final authController = _AuthedController(authRepository)..restoreSession();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: state),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ProviderMarketplaceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    List<MarketplaceCity> cities = const [],
    String? cityId,
  }) : citiesData = cities,
       cityIdData = cityId,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<MarketplaceCity> citiesData;
  String? cityIdData;
  final setCityCalls = <String?>[];

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => null;

  @override
  String get search => '';

  @override
  String? get cityId => cityIdData;

  @override
  String? get categoryId => null;

  @override
  List<MarketplaceCity> get cities => citiesData;

  @override
  List<ProviderCategory> get categories => const [];

  @override
  List<MarketplaceProvider> get providers => const [];

  @override
  Set<String> get favoriteProviderIds => const {};

  @override
  List<QuoteRequest> get quoteRequests => const [];

  @override
  bool get includesAccountData => true;

  @override
  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {}

  @override
  Future<void> setCity(String? id) async {
    setCityCalls.add(id);
    cityIdData = id;
    notifyListeners();
  }

  @override
  Future<void> setSearch(String value) async {}
}

class _AuthedController extends AuthController {
  _AuthedController(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}
