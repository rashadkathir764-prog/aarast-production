import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('account notifications gate before protected API calls', (
    tester,
  ) async {
    final fakeApi = _FakeNotificationsApi();
    await _pumpNotifications(tester, fakeApi, const NotificationsScreen());

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    expect(find.text('سجّل الدخول لعرض التنبيهات'), findsOneWidget);
    expect(find.text('لا توجد تنبيهات مهمة الآن.'), findsNothing);
    expect(fakeApi.getNotificationsCalls, 0);
    expect(fakeApi.getUnreadCountCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local plan notifications stay open without account API calls', (
    tester,
  ) async {
    final fakeApi = _FakeNotificationsApi();
    await _pumpNotifications(
      tester,
      fakeApi,
      const NotificationsScreen(weddingPlanId: 'guest-plan-test'),
    );

    expect(find.byKey(const Key('sharing-auth-gate')), findsNothing);
    expect(find.text('تنبيهات الخطة المحفوظة'), findsOneWidget);
    expect(find.text('لا توجد تنبيهات مهمة الآن.'), findsOneWidget);
    expect(fakeApi.getNotificationsCalls, 0);
    expect(fakeApi.getUnreadCountCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications account gate remains stable at 320px RTL width', (
    tester,
  ) async {
    final fakeApi = _FakeNotificationsApi();
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpNotifications(tester, fakeApi, const NotificationsScreen());

    expect(find.text('سجّل الدخول لعرض التنبيهات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester,
  _FakeNotificationsApi fakeApi,
  Widget screen,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(fakeApi),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi() : super(ApiClient(tokenProvider: () async => null));

  int getNotificationsCalls = 0;
  int getUnreadCountCalls = 0;

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    getNotificationsCalls += 1;
    return NotificationsPage(
      items: const [],
      page: page,
      limit: limit,
      total: 0,
      totalPages: 0,
      hasMore: false,
    );
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async {
    getUnreadCountCalls += 1;
    return 0;
  }
}
