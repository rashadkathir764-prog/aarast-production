import 'package:aarast_mobile/core/offline/side_outboxes.dart';
import 'package:aarast_mobile/features/chat/data/chat_outbox.dart';
import 'package:aarast_mobile/features/more/widgets/logout_sheet.dart';
import 'package:aarast_mobile/features/provider_portal/data/provider_offer_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-101: chat messages and offers waiting on the phone stayed after a
// sign-out the person chose, went out at the next sign-in, and «الخروج»
// did not name them.

Future<SharedPreferences> _withWaitingMessage() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await ChatOutbox(preferences).write('user-1', [
    ChatOutboxMessage(
      localId: 'm1',
      conversationId: 'c1',
      body: 'السلام عليكم',
      clientRequestId: 'r1',
      createdAt: DateTime.utc(2026, 11, 13),
    ),
  ]);
  return preferences;
}

void main() {
  tearDown(SideOutboxes.reset);

  test('a chosen sign-out takes the waiting messages and offers', () async {
    final preferences = await _withWaitingMessage();
    await preferences.setString('aarast_provider_offer_queue:provider-1', '[]');
    expect(ChatOutbox.countAll(preferences), 1);

    await ChatOutbox.clearAll(preferences);
    await ProviderOfferQueue.clearAll(preferences);

    expect(ChatOutbox(preferences).read('user-1'), isEmpty);
    expect(
      preferences.getKeys().where((key) => key.startsWith('aarast_')),
      isEmpty,
    );
  });

  testWidgets('«الخروج» names a waiting message', (tester) async {
    final preferences = await _withWaitingMessage();
    SideOutboxes.register(() => ChatOutbox.countAll(preferences));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LogoutSheet(sync: null)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-logout-unsent')), findsOneWidget);
    expect(find.textContaining('تغيير واحد'), findsOneWidget);
  });
}
