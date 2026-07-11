// Visual preview for the notifications feed — renders the REAL
// NotificationsScreen with a fake API (no hand-rebuilt card replica, so the
// golden can never drift from the production widget again).
//
// Regenerate with:
//   flutter test test/notifications_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('notifications — tone feed (430)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    await authStorage.saveSession(
      accessToken: 'notifications-preview-token',
      user: const SafeUser(
        id: 'user-1',
        name: 'رشاد',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );

    final api = _FakeNotificationsApi([
      _notification(
        id: 'n-1',
        type: 'QUOTE_RECEIVED',
        title: 'عرض سعر جديد',
        body: 'قاعة اللؤلؤة أرسلت لك عرض سعر لطلبك.',
        priority: 'HIGH',
        unread: true,
        hoursAgo: 1,
      ),
      _notification(
        id: 'n-2',
        type: 'INSTALLMENT_DUE',
        title: 'قسط قريب الاستحقاق',
        body: 'لديك قسط بقيمة 100,000 ريال يستحق خلال 3 أيام.',
        unread: false,
        hoursAgo: 4,
      ),
      _notification(
        id: 'n-3',
        type: 'SHARING_INVITE',
        title: 'دعوة مشاركة جديدة',
        body: 'انضم أحمد إلى خطة زفافك كمساهم.',
        unread: true,
        hoursAgo: 26,
      ),
      _notification(
        id: 'n-4',
        type: 'INSTALLMENT_OVERDUE',
        title: 'قسط متأخر',
        body: 'تجاوز قسط القاعة موعد استحقاقه. يرجى المتابعة.',
        priority: 'URGENT',
        unread: true,
        hoursAgo: 30,
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<NotificationsProvider>(
            create: (_) => NotificationsProvider(api),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const NotificationsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('عرض سعر جديد'), findsOneWidget);
    expect(find.text('قسط متأخر'), findsOneWidget);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/notifications_feed.png'),
    );
  });
}

AarastNotification _notification({
  required String id,
  required String type,
  required String title,
  required String body,
  required bool unread,
  required int hoursAgo,
  String priority = 'NORMAL',
}) {
  final createdAt = DateTime(2026, 7, 10, 12).subtract(
    Duration(hours: hoursAgo),
  );
  return AarastNotification(
    id: id,
    userId: 'user-1',
    type: type,
    title: title,
    body: body,
    priority: priority,
    createdAt: createdAt,
    updatedAt: createdAt,
    readAt: unread ? null : createdAt,
  );
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this._items)
    : super(ApiClient(tokenProvider: () async => null));

  final List<AarastNotification> _items;

  @override
  Future<List<AarastNotification>> getNotifications({
    String? weddingPlanId,
  }) async {
    return _items;
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async {
    return _items.where((item) => item.isUnread).length;
  }
}
