import 'package:aarast_mobile/features/notifications/utils/notification_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote conversation notifications are safe app routes', () {
    expect(
      isSafeNotificationRouteTarget('/conversations/conversation-1'),
      isTrue,
    );
  });

  test('external and unknown notification routes stay blocked', () {
    expect(
      isSafeNotificationRouteTarget('https://example.com/conversations/1'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/admin/users'), isFalse);
  });
}
