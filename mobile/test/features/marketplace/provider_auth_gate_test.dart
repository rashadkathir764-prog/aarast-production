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
  testWidgets(
    'providers marketplace route is public for guest users (Phase 3)',
    (tester) async {
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
          // Phase 3 contract: browsing /providers is public — no auth gate.
          GoRoute(
            path: AppRouter.providerMarketplace,
            builder: (context, state) =>
                const Scaffold(body: Text('providers-opened')),
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

      expect(find.byKey(const Key('provider-auth-gate')), findsNothing);
      expect(find.text('providers-opened'), findsOneWidget);
      expect(find.text('login'), findsNothing);
    },
  );

  testWidgets(
    'providers quote-request route still gates guest users (Phase 3)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = AuthController(authRepository)..restoreSession();
      final router = GoRouter(
        initialLocation: '/providers/p-1/quote',
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
          GoRoute(
            path: '/providers/:id/quote',
            builder: (context, state) => ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              child: const Text('quote-opened'),
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
      expect(find.text('quote-opened'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-auth-gate-login')));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
    },
  );
}
