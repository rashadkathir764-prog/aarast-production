import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const localPlanId = 'guest-plan-test';

  testWidgets('money screen opens without the local exploration placeholder', (
    tester,
  ) async {
    await _pumpWithProviders(
      tester,
      const MoneyOverviewScreen(weddingPlanId: localPlanId),
    );

    expect(find.text('المال'), findsOneWidget);
    expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
    expect(find.text('وضع تجربة التصميم'), findsNothing);
  });

  testWidgets('tasks screen opens without the local exploration placeholder', (
    tester,
  ) async {
    await _pumpWithProviders(
      tester,
      const TaskTimelineScreen(weddingPlanId: localPlanId),
    );

    expect(find.text('المهام'), findsWidgets);
    expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
    expect(find.text('وضع تجربة التصميم'), findsNothing);
  });

  testWidgets('guests screen opens without the local exploration placeholder', (
    tester,
  ) async {
    await _pumpWithProviders(
      tester,
      const GuestListScreen(weddingPlanId: localPlanId),
    );

    expect(find.text('الضيوف'), findsWidgets);
    expect(
      find.text(
        'لا يوجد ضيوف بعد. أضف ضيفًا عندما تكون لديك بيانات حضور فعلية.',
      ),
      findsOneWidget,
    );
    expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
    expect(find.text('وضع تجربة التصميم'), findsNothing);
  });

  testWidgets(
    'notifications screen opens without the local exploration placeholder',
    (tester) async {
      await _pumpWithProviders(
        tester,
        const NotificationsScreen(weddingPlanId: localPlanId),
      );

      expect(find.text('التنبيهات'), findsOneWidget);
      expect(find.text('لا توجد تنبيهات مهمة الآن.'), findsOneWidget);
      expect(find.text('أنت في وضع تجربة محلية'), findsNothing);
      expect(find.text('وضع تجربة التصميم'), findsNothing);
    },
  );
}

Future<void> _pumpWithProviders(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(FinanceApi(apiClient)),
        ),
        ChangeNotifierProvider<TaskTimelineProvider>(
          create: (_) => TaskTimelineProvider(TaskTimelineApi(apiClient)),
        ),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(GuestsApi(apiClient)),
        ),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(NotificationsApi(apiClient)),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}
