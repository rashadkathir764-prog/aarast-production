import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invitations.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:aarast_mobile/features/guests/widgets/invitation_queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/preview_fonts.dart';
import '../../support/app_text_scale.dart';

// D116: a round of sends from the person's own WhatsApp. Each guest's turn
// opens the server's text in the guest's chat; only the person says it was
// sent, and that is what settles the prepared send. A send prepared before
// and never answered is asked about first, so nobody gets it twice.

Guest _guest(
  String id,
  String name, {
  String? phone = '+967777000111',
  GuestLastSend? lastSend,
}) => Guest(
  id: id,
  weddingPlanId: 'plan-1',
  name: name,
  phone: phone,
  side: 'GROOM',
  status: 'INVITED',
  seatsCount: 1,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  lastSend: lastSend,
);

class _Api extends GuestsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final links = <({String guestId, String? kind, String? planEventId})>[];
  final settled = <(String, bool)>[];
  bool settleFails = false;

  @override
  Future<GuestInvitationLink> createInvitationLink(
    String guestId, {
    bool reminder = false,
    String? kind,
    String? planEventId,
    String? channel,
  }) async {
    links.add((guestId: guestId, kind: kind, planEventId: planEventId));
    return GuestInvitationLink(
      url: 'https://site/rsvp/$guestId',
      message: 'نص الخادم $guestId',
      sendId: 'send-$guestId',
      kind: kind ?? 'INVITATION',
    );
  }

  @override
  Future<void> settleInvitationSend(
    String sendId, {
    required bool sent,
    String? channel,
  }) async {
    if (settleFails) throw const ApiException('ما وصلنا', statusCode: 503);
    settled.add((sendId, sent));
  }
}

const _channel = MethodChannel('plugins.flutter.io/url_launcher');

/// Opens the queue for [turns] from a button, and keeps what it closed with.
Future<({_Api api, List<int?> results})> _pump(
  WidgetTester tester,
  List<InvitationTurn> turns,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 900);
  addTearDown(tester.view.reset);
  final api = _Api();
  final results = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      // The phone's own fonts at 140% text, as walks are judged.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: appTextScaler(1.3)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                results.add(
                  await showJourneySheet<int>(
                    context: context,
                    isDismissible: false,
                    builder: (_) => InvitationQueueSheet(
                      turns: turns,
                      api: api,
                      title: 'إرسال الدعوات',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (api: api, results: results);
}

String _current(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('queue-guest'))).data!;

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late List<String> launched;

  setUpAll(loadPreviewAppFonts);

  setUp(() {
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('each turn opens the text, then settles what the person says', (
    tester,
  ) async {
    final (:api, :results) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
      (
        guest: _guest('b', 'مراد', phone: '+967777000222'),
        kind: InvitationSendKind.addition,
        planEventId: 'lunch',
      ),
    ]);

    expect(_current(tester), 'ياسر');
    expect(find.text('التالي 1 من 2'), findsOneWidget);
    // Nothing is prepared before the person asks for it.
    expect(api.links, isEmpty);
    expect(find.byKey(const ValueKey('queue-sent')), findsNothing);

    await _tap(tester, 'queue-open-text');
    expect(api.links.single, (
      guestId: 'a',
      kind: 'INVITATION',
      planEventId: null,
    ));
    final chat = Uri.parse(launched.single);
    expect(chat.host, 'wa.me');
    expect(chat.path, '/967777000111');
    expect(chat.queryParameters['text'], 'نص الخادم a');
    // Opening WhatsApp is not sending: nothing is settled yet.
    expect(api.settled, isEmpty);

    await _tap(tester, 'queue-sent');
    expect(api.settled, [('send-a', true)]);
    expect(_current(tester), 'مراد');
    expect(find.text('التالي 2 من 2'), findsOneWidget);

    await _tap(tester, 'queue-open-text');
    expect(api.links.last, (
      guestId: 'b',
      kind: 'ADDITION',
      planEventId: 'lunch',
    ));
    await _tap(tester, 'queue-not-sent');
    expect(api.settled, [('send-a', true), ('send-b', false)]);

    expect(find.byKey(const ValueKey('queue-done')), findsOneWidget);
    expect(find.text('انرسلت لـ 1 من 2'), findsOneWidget);
    await _tap(tester, 'queue-close');
    expect(results, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a send prepared before is asked about first', (tester) async {
    final earlier = GuestLastSend(
      id: 'old-a',
      kind: 'INVITATION',
      status: 'PREPARED',
      createdAt: DateTime(2026, 11, 1),
    );
    final (:api, :results) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر', lastSend: earlier),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
      (
        guest: _guest('b', 'مراد'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
    ]);

    expect(find.byKey(const ValueKey('queue-earlier')), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-open-text')), findsNothing);

    // «انرسلت»: the earlier send is settled and the guest is done.
    await _tap(tester, 'queue-earlier-sent');
    expect(api.settled, [('old-a', true)]);
    expect(api.links, isEmpty, reason: 'nothing more is prepared for them');
    expect(_current(tester), 'مراد');
    expect(find.byKey(const ValueKey('queue-earlier')), findsNothing);

    await _tap(tester, 'queue-stop');
    expect(results, [0]);
  });

  testWidgets('an earlier send that did not go is settled, then sent again', (
    tester,
  ) async {
    final earlier = GuestLastSend(
      id: 'old-a',
      kind: 'REMINDER',
      status: 'PREPARED',
      createdAt: DateTime(2026, 11, 1),
    );
    final (:api, results: _) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر', lastSend: earlier),
        kind: InvitationSendKind.reminder,
        planEventId: null,
      ),
    ]);

    await _tap(tester, 'queue-earlier-not-sent');
    expect(api.settled, [('old-a', false)]);
    expect(_current(tester), 'ياسر');
    expect(find.byKey(const ValueKey('queue-open-text')), findsOneWidget);
    expect(find.text('تذكير'), findsOneWidget);
  });

  testWidgets('a number without its country prepares nothing', (tester) async {
    expect(guestChatCanOpen('966501234567'), isFalse);
    final (:api, results: _) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر', phone: '966501234567'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
    ]);

    await _tap(tester, 'queue-open-text');
    expect(find.byKey(const ValueKey('queue-error')), findsOneWidget);
    expect(find.text(guestNumberWithoutCountry('ياسر')), findsOneWidget);
    expect(api.links, isEmpty);
    expect(launched, isEmpty);
    expect(find.byKey(const ValueKey('queue-sent')), findsNothing);
  });

  testWidgets('a skipped guest is not settled; stop closes with the count', (
    tester,
  ) async {
    final (:api, :results) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
      (
        guest: _guest('b', 'مراد'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
      (
        guest: _guest('c', 'فهد'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
    ]);

    await _tap(tester, 'queue-open-text');
    await _tap(tester, 'queue-sent');
    await _tap(tester, 'queue-skip');
    expect(_current(tester), 'فهد');
    expect(api.links.map((link) => link.guestId), ['a']);
    expect(api.settled, [('send-a', true)]);

    await _tap(tester, 'queue-stop');
    expect(results, [1]);
    expect(find.byKey(const ValueKey('queue-guest')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settle that fails is said, and the turn stays', (
    tester,
  ) async {
    final (:api, results: _) = await _pump(tester, [
      (
        guest: _guest('a', 'ياسر'),
        kind: InvitationSendKind.invitation,
        planEventId: null,
      ),
    ]);

    await _tap(tester, 'queue-open-text');
    api.settleFails = true;
    await _tap(tester, 'queue-sent');
    expect(find.text('ما وصلنا'), findsOneWidget);
    expect(_current(tester), 'ياسر');
    expect(find.byKey(const ValueKey('queue-sent')), findsOneWidget);

    api.settleFails = false;
    await _tap(tester, 'queue-sent');
    expect(api.settled, [('send-a', true)]);
    expect(find.byKey(const ValueKey('queue-done')), findsOneWidget);
  });
}
