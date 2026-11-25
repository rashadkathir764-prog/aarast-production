import 'package:aarast_mobile/core/push/open_conversation.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

// A push in front is shown by the app on the server's channel and under its
// tag (`push-delivery.service.ts`), so it lands where the person muted or
// allowed that kind, and a chat's next message replaces its last one.

void main() {
  test('a push with no channel takes the one the server maps its type to', () {
    expect(pushAndroidChannelFor('TASK_DUE_SOON'), 'aarast_tasks');
    expect(pushAndroidChannelFor('WEDDING_COUNTDOWN'), 'aarast_tasks');
    expect(pushAndroidChannelFor('PAYMENT_SCHEDULE_OVERDUE'), 'aarast_money');
    expect(pushAndroidChannelFor('FUNDING_EXPECTED'), 'aarast_money');
    expect(pushAndroidChannelFor('CHAT_MESSAGE_RECEIVED'), 'aarast_messages');
    expect(pushAndroidChannelFor('PROVIDER_APPROVED'), 'aarast_messages');
    expect(pushAndroidChannelFor(null), 'aarast_messages');
  });

  test('a chat push names its conversation, by the server or by its tag', () {
    expect(pushConversationId({'conversationId': 'c-1'}, null), 'c-1');
    expect(pushConversationId(const {}, 'aarast_chat_c-2'), 'c-2');
    expect(pushConversationId(const {}, 'aarast_n-1'), isNull);
    expect(pushConversationId(const {}, 'aarast_chat_'), isNull);
    expect(pushConversationId(const {}, null), isNull);
  });

  test('the conversation on the screen is the last one opened, until it '
      'closes', () {
    final open = OpenConversationRegistry();
    expect(open.isOpen('c-1'), isFalse);

    open.opened('c-1');
    expect(open.isOpen('c-1'), isTrue);

    open.opened('c-2');
    open.closed('c-1');
    expect(open.isOpen('c-2'), isTrue, reason: 'c-1 was not the one open');

    open.closed('c-2');
    expect(open.current, isNull);
  });
}
