import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final providerMode in [false, true]) {
    testWidgets('RegisterScreen is RTL and overflow-free at 320px '
        '${providerMode ? 'for providers' : 'for customers'}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.reset);

      final auth = await _authController();
      final marketplace = _ReferenceDataMarketplaceProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: RegisterScreen(startAsProvider: providerMode),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'provider registration retries reference loading and enables both selectors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final auth = await _authController();
      final marketplace = ProviderMarketplaceProvider(
        _RetryingReferenceDataApi(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: RegisterScreen(startAsProvider: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل خيارات المدينة والفئة.'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      final cityField = find.byKey(const Key('provider-city-dropdown'));
      final categoryField = find.byKey(const Key('provider-category-dropdown'));
      expect(cityField, findsOneWidget);
      expect(categoryField, findsOneWidget);

      await tester.ensureVisible(cityField);
      await tester.tap(cityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('صنعاء').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(categoryField);
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الصالات').last);
      await tester.pumpAndSettle();

      expect(find.text('صنعاء'), findsOneWidget);
      expect(find.text('الصالات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(AuthRepository(client, storage));
}

class _ReferenceDataMarketplaceProvider extends ProviderMarketplaceProvider {
  _ReferenceDataMarketplaceProvider()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  Future<void> loadReferenceData() async {}
}

class _RetryingReferenceDataApi extends MarketplaceApi {
  _RetryingReferenceDataApi()
    : super(ApiClient(tokenProvider: () async => null));

  var _cityAttempts = 0;

  @override
  Future<List<MarketplaceCity>> getCities() async {
    _cityAttempts += 1;
    if (_cityAttempts == 1) {
      throw const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      );
    }
    return const [MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء')];
  }

  @override
  Future<List<ProviderCategory>> getCategories() async {
    return const [ProviderCategory(id: 'category-halls', nameAr: 'الصالات')];
  }
}
