import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/home/providers/home_dashboard_provider.dart';
import 'package:aarast_mobile/features/home/screens/home_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430, 600, 900]) {
    testWidgets('home dashboard has no layout exceptions at ${width}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final authRepository = AuthRepository(apiClient, storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthController(authRepository),
            ),
            ChangeNotifierProvider(
              create: (_) => HomeDashboardProvider(
                weddingPlansApi: _FakeWeddingPlansApi(apiClient),
                sharingApi: _FakeSharingApi(apiClient),
              ),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(home: HomeScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _FakeWeddingPlansApi extends WeddingPlansApi {
  _FakeWeddingPlansApi(super.apiClient);

  @override
  Future<List<WeddingPlan>> getMyWeddingPlans() async => [
    WeddingPlan(
      id: 'plan-1',
      ownerUserId: 'user-1',
      title: 'خطة زفاف تجريبية طويلة',
      city: 'صنعاء',
      weddingDate: DateTime(2030, 1, 1),
      estimatedBudget: '2500000',
      currency: 'YER',
      status: 'PLANNING',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi(super.apiClient);

  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async => const [];
}
