import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/screens/active_plan_onboarding_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('completes visible onboarding and opens dashboard route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'aarast_access_token': 'token'});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final guestStorage = GuestOnboardingStorage(preferences);
    late RequestOptions capturedRequest;
    final provider = WeddingPlansProvider(
      WeddingPlansApi(
        _client((options) {
          capturedRequest = options;
          return _onboardingResponseJson();
        }),
      ),
    );
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const ActivePlanOnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Directionality(
            textDirection: TextDirection.rtl,
            child: Text('dashboard-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<GuestOnboardingStorage>.value(value: guestStorage),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-create-plan'));
    await tester.pumpAndSettle();

    expect(capturedRequest.path, '/api/v1/onboarding/complete');
    expect(capturedRequest.data['path'], 'USER');
    expect(provider.activePlan?.id, 'plan-1');
    expect(authStorage.readActivePlanId(), 'plan-1');
    expect(find.text('dashboard-opened'), findsOneWidget);
  });

  testWidgets('creates local guest plan without calling protected API', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final guestStorage = GuestOnboardingStorage(preferences);
    var apiCallCount = 0;
    final provider = WeddingPlansProvider(
      WeddingPlansApi(
        _client((options) {
          apiCallCount += 1;
          return _onboardingResponseJson();
        }),
      ),
    );
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const ActivePlanOnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Directionality(
            textDirection: TextDirection.rtl,
            child: Text('local-dashboard-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          Provider<GuestOnboardingStorage>.value(value: guestStorage),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-primary-action'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('active-onboarding-create-plan'));
    await tester.pumpAndSettle();

    final guestPlan = await guestStorage.loadGuestPlan();
    expect(apiCallCount, 0);
    expect(guestPlan, isNotNull);
    expect(guestPlan!.guestPlanId, startsWith('guest-plan-'));
    expect(guestPlan.isGuestPlan, isTrue);
    expect(guestPlan.needsSync, isTrue);
    expect(guestPlan.createdAt, isNotNull);
    expect(find.text('local-dashboard-opened'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  final view = tester.view;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  for (var attempt = 0; attempt < 8; attempt += 1) {
    final center = tester.getCenter(finder, warnIfMissed: false);
    if (center.dy > 0 && center.dy < logicalSize.height) {
      await tester.tap(finder, warnIfMissed: false);
      return;
    }
    await tester.drag(
      find.byType(CustomScrollView),
      Offset(0, center.dy >= logicalSize.height ? -320 : 320),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(finder, warnIfMissed: false);
}

ApiClient _client(Object? Function(RequestOptions options) responder) {
  final client = ApiClient(tokenProvider: () async => 'token');
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: responder(options),
          ),
        );
      },
    ),
  );
  return client;
}

Map<String, dynamic> _onboardingResponseJson() {
  return {
    'user': {
      'id': 'user-1',
      'name': 'سارة',
      'phone': '+967777000000',
      'role': 'USER',
      'status': 'ACTIVE',
    },
    'activeWeddingPlan': {
      'id': 'plan-1',
      'ownerUserId': 'user-1',
      'title': 'خطة زفاف صنعاء',
      'city': 'صنعاء',
      'location': {'city': 'صنعاء'},
      'weddingDate': '2026-12-24T00:00:00.000Z',
      'priorities': ['budget', 'tasks'],
      'estimatedBudget': '120000.00',
      'currency': 'SAR',
      'onboardingPath': 'USER',
      'persona': 'BRIDE',
      'onboardingCompletedAt': '2026-06-19T10:00:00.000Z',
      'status': 'PLANNING',
      'createdAt': '2026-06-19T10:00:00.000Z',
      'updatedAt': '2026-06-19T10:00:00.000Z',
    },
    'budgetCategories': const [],
  };
}
