import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/quote_request_screen.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'non-local task submit without token shows cloud auth message and does not save',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final taskProvider = TaskTimelineProvider(TaskTimelineApi(apiClient));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<TaskTimelineProvider>.value(
              value: taskProvider,
            ),
          ],
          child: const MaterialApp(
            home: CreateTaskScreen(weddingPlanId: 'plan-test'),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'مهمة تجريبية',
      );
      final submit = find.text('حفظ المهمة');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(
        find.text('سجّل الدخول لحفظ هذا الإجراء على حسابك ومزامنته.'),
        findsOneWidget,
      );
      expect(taskProvider.tasks, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quote form requires an account before protected submit actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final authRepository = AuthRepository(apiClient, authStorage);
      final authController = AuthController(authRepository)..restoreSession();
      final marketplaceProvider = _NoopMarketplaceProvider(apiClient);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<AuthRepository>.value(value: authRepository),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplaceProvider,
            ),
            ChangeNotifierProvider<WeddingPlansProvider>(
              create: (_) => WeddingPlansProvider(WeddingPlansApi(apiClient)),
            ),
          ],
          child: const MaterialApp(
            home: QuoteRequestScreen(providerId: 'provider-test'),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      // f07 wording (D15).
      expect(find.text('اطلب عرض سعر'), findsOneWidget);
      expect(find.text('ادخل حسابك أول'), findsOneWidget);
      expect(find.text('كلمة لهم (اختياري)'), findsNothing);
      expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
      expect(marketplaceProvider.createQuoteAttempted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoopMarketplaceProvider extends ProviderMarketplaceProvider {
  _NoopMarketplaceProvider(ApiClient apiClient)
    : super(MarketplaceApi(apiClient));

  bool createQuoteAttempted = false;

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<void> loadReferenceData() async {}

  @override
  MarketplaceProvider? providerDetails(String id) => null;

  @override
  List<MarketplaceService> servicesFor(String id) => const [];

  @override
  Future<bool> createQuoteRequest({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    createQuoteAttempted = true;
    return false;
  }
}
