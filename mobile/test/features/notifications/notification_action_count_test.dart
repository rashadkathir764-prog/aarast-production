import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// The action goes; the unread count read after it fails.
class _CountFailsApi extends NotificationsApi {
  _CountFailsApi() : super(ApiClient(tokenProvider: () async => null));

  int archived = 0;

  @override
  Future<AarastNotification> archiveNotification(String id) async {
    archived += 1;
    return _notice;
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async =>
      throw const ApiException('حدث خطأ في الخادم.', statusCode: 503);
}

final _notice = AarastNotification(
  id: 'n1',
  userId: 'u1',
  type: 'TASK_DUE_SOON',
  title: 'تذكير',
  body: 'مهمة',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  // The count after an action is a read: its failure said «تعذر أرشفة
  // التنبيه» over a notice that was archived.
  test('an archived notice is archived even when the count read fails', () async {
    final api = _CountFailsApi();
    final notices = NotificationsProvider(api);

    expect(await notices.archiveNotification(_notice), isTrue);
    expect(api.archived, 1);
    expect(notices.errorMessage, isNull);
  });
}
