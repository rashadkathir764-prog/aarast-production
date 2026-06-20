import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('providers route requires login for guest users', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final authRepository = AuthRepository(apiClient, authStorage);
    final authController = AuthController(authRepository)..restoreSession();
    final router = GoRouter(
      initialLocation: AppRouter.providerMarketplace,
      routes: [
        GoRoute(
          path: AppRouter.login,
          builder: (context, state) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: AppRouter.providerMarketplace,
          builder: (context, state) => const ProviderAuthGate(
            resumeLocation: AppRouter.providerMarketplace,
            child: Text('providers-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<AuthRepository>.value(value: authRepository),
          ChangeNotifierProvider<AuthController>.value(value: authController),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider-auth-gate')), findsOneWidget);
    expect(find.text('providers-opened'), findsNothing);
    expect(
      find.text(
        'تصفح الموردين وطلب عروض الأسعار يحتاج حسابًا لحفظ طلباتك ومتابعتها.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('provider-auth-gate-login')));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['resume'],
      AppRouter.providerMarketplace,
    );
  });
}
