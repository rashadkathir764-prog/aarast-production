import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/guests/screens/guest_send_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

// D116 «إرسال الدعوات»: how (one invitation with every occasion of the
// guest, or one per occasion), for which occasion's guests, and to whom:
// those never told, those holding an old day or place, those told and
// silent. It names who cannot be sent to and why, and the round needs the
// network.

const _plan = 'plan-1';

GuestToldOccasion _told(String event) => GuestToldOccasion(
  planEventId: event,
  version: 1,
  at: DateTime(2026, 11, 2),
);

Guest _guest(
  String id,
  String name, {
  String planId = _plan,
  String status = 'INVITED',
  String? phone = '+967777000111',
  List<String> lunch = const [],
  List<GuestToldOccasion> told = const [],
  bool editable = true,
}) => Guest(
  id: id,
  weddingPlanId: planId,
  name: name,
  phone: phone,
  side: 'GROOM',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: told.isEmpty ? 'NOT_SENT' : 'SENT',
  seatsCount: 1,
  editable: editable,
  events: [for (final id in lunch) GuestEventReply(planEventId: id)],
  told: told,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

/// Yasser comes to the wedding and is silent on the lunch; Murad is silent
/// on the wedding; Fahd was never told (lunch too); Sami has no number;
/// Nabil's number has no country; Hani was told of the wedding but not of
/// the lunch he was added to since; the owner's guest is not this reader's.
List<Guest> _guests() => [
  _guest(
    'a',
    'ياسر',
    status: 'CONFIRMED',
    lunch: const ['lunch'],
    told: [_told('wedding-1'), _told('lunch')],
  ),
  _guest('b', 'مراد', told: [_told('wedding-1')]),
  _guest('c', 'فهد', lunch: const ['lunch']),
  _guest('d', 'سامي', phone: null),
  _guest('e', 'نبيل', phone: '966501234567'),
  _guest('g', 'هاني', lunch: const ['lunch'], told: [_told('wedding-1')]),
  _guest('o', 'خالد', editable: false),
];

class _Api extends GuestsApi {
  _Api(this.guests) : super(ApiClient(tokenProvider: () async => null));

  final List<Guest> guests;
  final links = <({String guestId, String? kind, String? planEventId})>[];

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: guests);

  @override
  Future<InvitationCard> getInvitationCard(String weddingPlanId) async =>
      const InvitationCard();

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
    );
  }

  @override
  Future<void> settleInvitationSend(
    String sendId, {
    required bool sent,
    String? channel,
  }) async {}
}

/// The plan's occasions: the wedding and a lunch.
class _Events extends PlanEventsProvider {
  _Events()
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  @override
  PlanEventsView? viewOf(String weddingPlanId) => PlanEventsView(
    weddingPlanId: weddingPlanId,
    canEdit: true,
    items: [
      const PlanEvent(id: 'wedding-1', type: PlanEventType.wedding),
      PlanEvent(
        id: 'lunch',
        type: PlanEventType.lunch,
        date: DateTime(2027, 1, 20),
      ),
    ],
    suggestions: const [],
  );

  @override
  Future<void> load(String weddingPlanId) async {}
}

Future<_Api> _pump(
  WidgetTester tester, {
  List<Guest>? guests,
  String planId = _plan,
  String? event,
  String? audience,
  OfflineSyncService? offline,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1600);
  addTearDown(tester.view.reset);
  final api = _Api(guests ?? _guests());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
        ChangeNotifierProvider<PlanEventsProvider>(create: (_) => _Events()),
        if (offline != null)
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
      ],
      child: MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: JourneyProfileScope(
            profile: JourneyProfile.groom,
            child: child!,
          ),
        ),
        home: GuestSendScreen(
          weddingPlanId: planId,
          initialEvent: event,
          initialAudience: audience,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// The count an audience chip says.
String _chip(WidgetTester tester, String audience) => tester
    .widget<JourneyChip>(find.byKey(ValueKey('send-audience-$audience')))
    .label;

JourneyButton _start(WidgetTester tester) =>
    tester.widget<JourneyButton>(find.byKey(const ValueKey('send-start')));

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  // The phone's own fonts: the test font's square letters are wider than any
  // Arabic word and overflow rows a real phone fits.
  setUpAll(loadPreviewAppFonts);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, null);
  });

  testWidgets('one invitation for every occasion counts each audience', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('send-unified')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-event-all')), findsOneWidget);
    // Never told of something: Fahd, Sami, Nabil, and Hani of the lunch.
    expect(_chip(tester, 'new'), endsWith(' 4'));
    expect(_chip(tester, 'change'), endsWith(' 0'));
    // Told and silent on something: Yasser (lunch), Murad, Hani (wedding).
    expect(_chip(tester, 'remind'), endsWith(' 3'));

    // The guests due: who can be reached, and who cannot and why.
    expect(find.byKey(const ValueKey('send-preview')), findsOneWidget);
    expect(find.textContaining('أهلًا فهد'), findsOneWidget);
    expect(find.text('فهد، هاني'), findsOneWidget);
    final unreachable = tester
        .widget<JourneyNote>(find.byKey(const ValueKey('send-unreachable')))
        .text;
    expect(unreachable, contains('بلا رقم: سامي'));
    expect(unreachable, contains('رقم بلا مفتاح الدولة: نبيل'));
    // The owner's guest is not this reader's to send to.
    expect(find.textContaining('خالد'), findsNothing);
    expect(_start(tester).onPressed, isNotNull);
    expect(_start(tester).label, contains('ضيفين'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the round sends each guest what they are due', (tester) async {
    final api = await _pump(tester);

    await _tap(tester, 'send-start');
    await _tap(tester, 'queue-open-text');
    await _tap(tester, 'queue-sent');
    await _tap(tester, 'queue-open-text');

    // One invitation: no occasion of its own; Hani, told before, is sent
    // the occasion added since.
    expect(api.links, [
      (guestId: 'c', kind: 'INVITATION', planEventId: null),
      (guestId: 'g', kind: 'ADDITION', planEventId: null),
    ]);
  });

  testWidgets('a reminder for one occasion leaves out who confirmed it', (
    tester,
  ) async {
    await _pump(tester, audience: 'remind');

    await _tap(tester, 'send-event-wedding-1');
    expect(_chip(tester, 'remind'), endsWith(' 2'));
    expect(find.text('مراد، هاني'), findsOneWidget);
    expect(find.textContaining('ياسر'), findsNothing);

    // On the lunch Yasser has not answered, and is reminded.
    await _tap(tester, 'send-event-lunch');
    expect(_chip(tester, 'remind'), endsWith(' 1'));
    expect(find.text('ياسر'), findsOneWidget);
    expect(find.textContaining('مراد'), findsNothing);
  });

  testWidgets('one invitation per occasion names that occasion', (
    tester,
  ) async {
    final api = await _pump(tester);

    await _tap(tester, 'send-separate');
    // Every occasion at once is for one invitation only.
    expect(find.byKey(const ValueKey('send-event-all')), findsNothing);
    await _tap(tester, 'send-event-lunch');
    expect(_chip(tester, 'new'), endsWith(' 2'));
    expect(find.text('فهد، هاني'), findsOneWidget);

    await _tap(tester, 'send-start');
    await _tap(tester, 'queue-open-text');
    await _tap(tester, 'queue-sent');
    await _tap(tester, 'queue-open-text');
    expect(api.links, [
      (guestId: 'c', kind: 'INVITATION', planEventId: 'lunch'),
      (guestId: 'g', kind: 'INVITATION', planEventId: 'lunch'),
    ]);
  });

  testWidgets('the screen opens on the occasion and audience it was sent', (
    tester,
  ) async {
    await _pump(tester, event: 'lunch', audience: 'remind');

    expect(
      tester
          .widget<JourneyChip>(find.byKey(const ValueKey('send-event-lunch')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<JourneyChip>(
            find.byKey(const ValueKey('send-audience-remind')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('ياسر'), findsOneWidget);
  });

  testWidgets('an audience with nobody in it says so and sends nothing', (
    tester,
  ) async {
    await _pump(tester, audience: 'change');

    expect(find.byKey(const ValueKey('send-nobody')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-preview')), findsNothing);
    expect(_start(tester).onPressed, isNull);
  });

  testWidgets('without the network the round does not start', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.noteNetworkFailure();
    await _pump(tester, offline: offline);

    expect(_start(tester).onPressed, isNull);
    expect(_start(tester).label, 'الإرسال يحتاج نت');
  });

  // A plan kept on the phone has no links on the server to send: its guests
  // tab offers no send and says why.
  testWidgets('a plan kept on the phone shows no send on its tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1400);
    addTearDown(tester.view.reset);
    final api = _Api([
      _guest('l1', 'فهد', planId: 'local-guest-plan'),
      _guest('l2', 'مراد', planId: 'local-guest-plan', status: 'CONFIRMED'),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestsApi>.value(value: api),
          ChangeNotifierProvider<GuestsProvider>(
            create: (_) => GuestsProvider(api),
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: GuestListScreen(weddingPlanId: 'local-guest-plan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('guests-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-doors-local')), findsOneWidget);
    for (final key in [
      'guests-send-new',
      'guests-send-change',
      'guests-send-remind',
      'guests-send-all-options',
      'guests-invite-card',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  // Opened by its address on a plan kept on the phone, the send screen
  // offers no round: no link can be made for it. Failed before the fix.
  testWidgets('a plan kept on the phone offers no round', (
    tester,
  ) async {
    await _pump(
      tester,
      planId: 'local-guest-plan',
      guests: [_guest('l1', 'فهد', planId: 'local-guest-plan')],
    );

    expect(_start(tester).onPressed, isNull);
  });
}
