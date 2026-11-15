import 'dart:convert';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invitations.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_invite_screen.dart';
import 'package:aarast_mobile/features/guests/widgets/invitation_message_preview.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// e04 «بطاقة الدعوة», D116: the invitation is prepared here and only here:
// the card's picture (none, a photo inside the card, a ready card), the
// words, and what a guest receives, word for word. Sending is «إرسال
// الدعوات» (guest_send_screen_test.dart); each occasion's day, place and map
// are its own (plan_event_sheet).

Guest _guest(
  String id,
  String name, {
  String? phone = '+967777000111',
  List<String> eventIds = const [],
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    events: [for (final id in eventIds) GuestEventReply(planEventId: id)],
    id: id,
    weddingPlanId: 'plan-1',
    name: name,
    phone: phone,
    side: 'GROOM',
    status: 'INVITED',
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class _Api extends GuestsApi {
  _Api(this.guests) : super(ApiClient(tokenProvider: () async => null));

  final List<Guest> guests;
  bool fail = false;
  bool cardFails = false;
  bool saveFails = false;
  InvitationCard card = const InvitationCard();
  final cardWrites = <Map<String, String?>>[];

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (fail) throw const ApiException('ما وصلنا', statusCode: 503);
    return guests;
  }

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
  Future<InvitationCard> getInvitationCard(String weddingPlanId) async {
    if (cardFails) throw const ApiException('ما وصلنا', statusCode: 503);
    return card;
  }

  @override
  Future<InvitationCard> setInvitationCard(
    String weddingPlanId,
    Map<String, String?> changes,
  ) async {
    if (saveFails) {
      throw const ApiException('الكلام طويل زيادة', statusCode: 400);
    }
    cardWrites.add(changes);
    String? pick(String key, String? before) => changes.containsKey(key)
        ? (changes[key]?.isEmpty ?? true ? null : changes[key])
        : before;
    card = InvitationCard(
      hostLine: pick('hostLine', card.hostLine),
      freeText: pick('freeText', card.freeText),
      photoUrl: pick('photoUrl', card.photoUrl),
      isReadyCard: changes.containsKey('photoKind')
          ? changes['photoKind'] == 'CARD'
          : card.isReadyCard,
      updatedAt: DateTime.utc(2026, 11, 3),
    );
    return card;
  }
}

/// The plan's events, read when [arrive] is called (as late as the test
/// wants), and every save kept.
class _Events extends PlanEventsProvider {
  _Events(this._wedding, {this.others = const []})
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  final PlanEvent? _wedding;
  final List<PlanEvent> others;
  bool _arrived = false;
  final saved = <PlanEventDraft>[];

  void arrive() {
    _arrived = true;
    notifyListeners();
  }

  @override
  PlanEventsView? viewOf(String weddingPlanId) => _arrived
      ? PlanEventsView(
          weddingPlanId: weddingPlanId,
          canEdit: true,
          items: [?_wedding, ...others],
          suggestions: const [],
        )
      : null;

  @override
  Future<void> load(String weddingPlanId) async {}

  @override
  Future<void> save(
    String weddingPlanId, {
    PlanEvent? event,
    PlanEventType? type,
    required PlanEventDraft draft,
  }) async {
    saved.add(draft);
  }
}

/// The plan in Sana'a: the place the card stands in while the wedding has
/// no venue.
class _Dashboard extends DashboardSummaryProvider {
  _Dashboard({Map<String, dynamic>? location})
    : _summary = DashboardSummary.fromJson({
        'planId': 'plan-1',
        'title': 'عرس محمد',
        'city': 'صنعاء',
        'location': ?location,
        'currency': 'YER',
        'status': 'PLANNING',
        'permissions': {'isOwner': true, 'role': 'OWNER'},
      }),
      super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );

  final DashboardSummary _summary;

  @override
  DashboardSummary? get summary => _summary;

  @override
  Future<void> loadDashboard(String weddingPlanId, {sharedMember}) async {}
}

/// Takes the picked photo up and answers with its stored address, which
/// the bucket keeps private.
class _Uploads extends MediaUploadApi {
  _Uploads() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MediaUploadTicket> uploadImage({
    required XFile file,
    required String purpose,
  }) async => const MediaUploadTicket(
    key: 'guest-invitation-card/owner-1/a.png',
    attachmentRef: '',
    uploadUrl: 'https://upload.example/a',
    publicUrl: 'https://media.example/guest-invitation-card/owner-1/a.png',
    contentType: 'image/png',
    byteSize: 68,
  );
}

/// A one-pixel PNG, enough for the picture to decode.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// The card screen under a router, so its «إرسال الدعوات» can open the send
/// screen's route.
Future<_Api> _pump(
  WidgetTester tester,
  List<Guest> guests, {
  InvitationCard card = const InvitationCard(),
  _Api? api,
  _Events? events,
  Map<String, dynamic>? location,
  bool dashboard = false,
  MediaUploadApi? uploads,
  OfflineSyncService? offline,
  Future<XFile?> Function(ImageSource source)? pickPhoto,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1400);
  addTearDown(tester.view.reset);
  final theApi = api ?? (_Api(guests)..card = card);
  final provider = GuestsProvider(theApi);
  if (!theApi.fail) await provider.loadGuests('plan-1');
  final router = GoRouter(
    initialLocation: '/wedding-plans/plan-1/guests/invite',
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/guests/invite',
        builder: (_, state) => GuestInviteScreen(
          weddingPlanId: state.pathParameters['id']!,
          pickPhoto: pickPhoto,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/send',
        builder: (_, state) => Text('send ${state.uri}'),
      ),
      GoRoute(
        path: '/wedding-plans/:id/events',
        builder: (_, state) => const Text('occasions screen'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: theApi),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        if (uploads != null) Provider<MediaUploadApi>.value(value: uploads),
        if (offline != null)
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
        if (events != null)
          ChangeNotifierProvider<PlanEventsProvider>.value(value: events),
        if (dashboard || location != null)
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: _Dashboard(location: location),
          ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return theApi;
}

/// The text the guest gets, word for word (the preview draws it as
/// WhatsApp does: bold without stars, links kept left to right).
String _message(WidgetTester tester) => tester
    .widget<InvitationMessagePreview>(
      find.descendant(
        of: find.byKey(const ValueKey('invite-message')),
        matching: find.byType(InvitationMessagePreview),
      ),
    )
    .text;

Finder _button(String key) => find.byKey(ValueKey(key));

void main() {
  // From the code review of the field-notes branch: the photo just picked
  // was drawn from its stored address, which the bucket keeps private, so
  // the slot made to show the guest's view said «ما قدرنا نعرض الصورة».
  // It is drawn from the picked file itself.
  testWidgets('a photo just picked is drawn in the preview', (tester) async {
    await _pump(
      tester,
      [_guest('g1', 'صالح')],
      uploads: _Uploads(),
      pickPhoto: (_) async => XFile.fromData(_pixel, name: 'a.png'),
    );

    // D116: choosing a photo without one asks for it at once.
    await tester.tap(_button('invite-picture-photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختر صورة'));
    await tester.pumpAndSettle();

    final photo = tester.widget<Image>(
      find.byKey(const ValueKey('invite-card-photo')),
    );
    expect(photo.image, isA<MemoryImage>());
    expect(find.text('ما قدرنا نعرض الصورة الحين'), findsNothing);
    expect(_button('invite-save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the WhatsApp link opens the guest chat with the text ready', () {
    final uri = guestWhatsAppUri('+967777000111', 'أهلًا')!;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777000111');
    expect(uri.queryParameters['text'], 'أهلًا');
  });

  test('the text writes the day and the time as the server does', () {
    // Changed on purpose (D116): GuestInviteCard.dateLine → the server text twin's day and time words.
    expect(invitationDay(DateTime(2027, 2, 18)), '18/2/2027');
    expect(invitationTimeLabel('AFTER_ISHA', null), 'بعد العشاء');
    expect(invitationTimeLabel('AFTER_ISHA', '20:30'), 'الساعة 20:30');
    expect(invitationTimeLabel(null, ' '), isNull);
  });

  // D116: the screen is the card's setup only.
  testWidgets('the card screen offers the picture, the words and the preview', (
    tester,
  ) async {
    await _pump(tester, [_guest('a', 'ياسر'), _guest('b', 'مراد')]);

    expect(_button('invite-picture-none'), findsOneWidget);
    expect(_button('invite-picture-photo'), findsOneWidget);
    expect(_button('invite-picture-readyCard'), findsOneWidget);
    expect(_button('invite-card'), findsOneWidget);
    expect(_button('invite-places'), findsOneWidget);
    // Changed on purpose (D116): the card's venue, map link and address fields → each occasion's own, in the occasion sheet.
    expect(_button('invite-place'), findsNothing);
    expect(_button('invite-map-url'), findsNothing);
    expect(_button('invite-address'), findsNothing);
    // Changed on purpose (D116): «أرسل لـ ضيفين» on this screen → «إرسال الدعوات» goes to the send screen.
    expect(_button('invite-send'), findsNothing);
    expect(_button('invite-go-send'), findsOneWidget);

    await tester.enterText(_button('invite-host'), 'عبدالرحمن الحمدي');
    await tester.pump();
    expect(
      _message(tester),
      contains('يتشرف عبدالرحمن الحمدي بدعوتكم لحضور زفافنا.'),
    );
    expect(_message(tester), startsWith('أهلًا ياسر'));
    // A change waits to be saved.
    expect(_button('invite-save'), findsOneWidget);
    expect(_button('invite-go-send'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing changed the button goes to sending', (
    tester,
  ) async {
    await _pump(tester, [_guest('a', 'ياسر')]);

    await tester.tap(_button('invite-go-send'));
    await tester.pumpAndSettle();
    expect(find.text('send /wedding-plans/plan-1/guests/send'), findsOneWidget);
  });

  testWidgets('the occasions link opens the occasions', (tester) async {
    await _pump(tester, [_guest('a', 'ياسر')]);

    await tester.ensureVisible(_button('invite-open-occasions'));
    await tester.tap(_button('invite-open-occasions'));
    await tester.pumpAndSettle();
    expect(find.text('occasions screen'), findsOneWidget);
  });

  testWidgets('D83: the saved card comes back, and a change is saved once', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      [_guest('a', 'ياسر')],
      card: const InvitationCard(
        hostLine: 'عبدالرحمن الحمدي',
        freeText: 'يا مرحبا بالحاضرين',
      ),
    );

    // What the account keeps opens filled in, in the fields and the text.
    expect(find.text('عبدالرحمن الحمدي'), findsWidgets);
    expect(_message(tester), contains('يا مرحبا بالحاضرين'));
    expect(_button('invite-go-send'), findsOneWidget);

    await tester.enterText(_button('invite-free-text'), 'حياكم الله');
    await tester.pump();
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();

    // Changed on purpose (D116): «احفظ وأرسل» saved then opened the sender → saving only saves; the button goes back to sending.
    expect(api.cardWrites, [
      {'freeText': 'حياكم الله'},
    ]);
    expect(_button('invite-go-send'), findsOneWidget);
    expect(find.text('انحفظت البطاقة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // D116: the picture's kind is saved with the card: a photo inside the
  // card Aarast lays out, or a ready card sent whole.
  testWidgets('a saved photo turned into a ready card saves its kind', (
    tester,
  ) async {
    final api = await _pump(tester, [
      _guest('a', 'ياسر'),
    ], card: const InvitationCard(photoUrl: 'https://media.example/a.png'));

    bool selected(String key) =>
        tester.widget<JourneyOption>(_button(key)).selected;
    expect(selected('invite-picture-photo'), isTrue);
    expect(_button('invite-go-send'), findsOneWidget);

    await tester.tap(_button('invite-picture-readyCard'));
    await tester.pumpAndSettle();
    expect(selected('invite-picture-readyCard'), isTrue);
    expect(selected('invite-picture-photo'), isFalse);
    // A ready card is shown whole, the card Aarast lays out is not drawn.
    expect(_button('invite-ready-card'), findsOneWidget);
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();

    expect(api.cardWrites, [
      {'photoKind': 'CARD'},
    ]);
    expect(_button('invite-go-send'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«بدون صورة» takes the saved photo off', (tester) async {
    final api = await _pump(
      tester,
      [_guest('a', 'ياسر')],
      card: const InvitationCard(
        photoUrl: 'https://media.example/a.png',
        isReadyCard: true,
      ),
    );

    await tester.tap(_button('invite-picture-none'));
    await tester.pumpAndSettle();
    expect(_button('invite-card-photo'), findsNothing);
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();

    expect(api.cardWrites, [
      {'photoUrl': ''},
    ]);
  });

  testWidgets('a picked photo is saved with its kind', (tester) async {
    final api = await _pump(
      tester,
      [_guest('a', 'ياسر')],
      uploads: _Uploads(),
      pickPhoto: (_) async => XFile.fromData(_pixel, name: 'a.png'),
    );

    await tester.tap(_button('invite-picture-readyCard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختر صورة'));
    await tester.pumpAndSettle();
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();

    expect(api.cardWrites, [
      {
        'photoUrl': 'https://media.example/guest-invitation-card/owner-1/a.png',
        'photoKind': 'CARD',
      },
    ]);
  });

  // RA-MO-225: going back dropped what was typed on the card, with no word.
  testWidgets('leaving a changed card asks first', (tester) async {
    final api = await _pump(tester, [_guest('a', 'ياسر')]);

    await tester.enterText(_button('invite-host'), 'أبو محمد');
    await tester.pump();
    await tester.tap(find.byTooltip('رجوع').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-card-leave')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invite-card-stay')));
    await tester.pumpAndSettle();
    expect(find.text('أبو محمد'), findsWidgets);
    expect(api.cardWrites, isEmpty);
  });

  // RA-MO-62: the card's place took the plan's city and saving wrote it over
  // the wedding's venue. D116: the place is the occasion's; the city only
  // stands in on the text, and nothing is saved to the occasion.
  testWidgets(
    'a wedding without a venue opens unchanged, the city in the text',
    (tester) async {
      final events = _Events(
        const PlanEvent(id: 'e-wedding', type: PlanEventType.wedding),
      )..arrive();
      await _pump(
        tester,
        [_guest('a', 'ياسر')],
        events: events,
        dashboard: true,
      );

      expect(_message(tester), contains('المكان: صنعاء'));
      expect(_message(tester), contains('لحضور عرس محمد.'));
      expect(_button('invite-go-send'), findsOneWidget);
      expect(events.saved, isEmpty);
    },
  );

  // From the review of the field-notes branch: the server writes «المكان»
  // from the plan's medium label (`locationLabel`), and the preview must
  // write the same (`planPlaceLabel`). Failed before the fix: the preview
  // stood in the plan's city alone.
  testWidgets(
    'the plan\'s place in the text is the one the server writes',
    (tester) async {
      final events = _Events(
        const PlanEvent(id: 'e-wedding', type: PlanEventType.wedding),
      )..arrive();
      await _pump(
        tester,
        [_guest('a', 'ياسر')],
        events: events,
        location: const {
          'shortLabel': 'أمانة العاصمة، صنعاء',
          'mediumLabel': 'أمانة العاصمة، صنعاء، حدة',
          'fullLabel': 'أمانة العاصمة، صنعاء، حدة، شارع الخمسين، جنب الجامع',
          'displayLabel': 'أمانة العاصمة، صنعاء، حدة، شارع الخمسين، جنب الجامع',
        },
      );

      expect(_message(tester), contains('المكان: أمانة العاصمة، صنعاء، حدة'));
      expect(_message(tester), isNot(contains('شارع الخمسين')));
    },
  );

  testWidgets('the hall read after the plan is the text\'s place', (
    tester,
  ) async {
    final events = _Events(
      const PlanEvent(
        id: 'e-wedding',
        type: PlanEventType.wedding,
        placeLabel: 'قاعة سبأ',
      ),
    );
    await _pump(tester, [_guest('a', 'ياسر')], events: events, dashboard: true);
    events.arrive();
    await tester.pumpAndSettle();

    expect(_message(tester), contains('المكان: قاعة سبأ'));
    expect(_message(tester), isNot(contains('صنعاء')));
    expect(_button('invite-go-send'), findsOneWidget);
    expect(events.saved, isEmpty);
  });

  testWidgets('the card that could not be read offers to read it again', (
    tester,
  ) async {
    final api = _Api([_guest('a', 'ياسر')])..cardFails = true;
    await _pump(tester, const [], api: api);

    expect(_button('invite-host'), findsNothing);
    final go = tester.widget<JourneyButton>(_button('invite-go-send'));
    expect(go.onPressed, isNull, reason: 'nothing to send from yet');
    api.cardFails = false;
    api.card = const InvitationCard(hostLine: 'أم سلمى');
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('أم سلمى'), findsWidgets);
  });

  // Changed on purpose (D116): a list that could not be read showed «ما فيه أحد ما وصلته دعوة» → the screen lists nobody; the preview speaks to a sample guest.
  testWidgets('without the guests the preview names a sample guest', (
    tester,
  ) async {
    final api = _Api([_guest('g1', 'ياسر')])..fail = true;
    await _pump(tester, const [], api: api);

    expect(_message(tester), startsWith('أهلًا اسم الضيف'));
    expect(tester.takeException(), isNull);
  });

  // D85: the card is kept on the phone with no connection.
  testWidgets('with no connection the card saves on the phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: ApiClient(tokenProvider: () async => null),
    );
    await offline.noteNetworkFailure();
    final api = await _pump(tester, [_guest('a', 'ياسر')], offline: offline);

    expect(_button('invite-offline'), findsOneWidget);
    await tester.enterText(_button('invite-host'), 'أبو محمد');
    await tester.pump();
    expect(find.text('احفظ البطاقة'), findsOneWidget);
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();
    expect(api.cardWrites, [
      {'hostLine': 'أبو محمد'},
    ]);
    expect(
      find.text('انحفظت البطاقة في جوالك، وتوصل لما يرجع النت'),
      findsOneWidget,
    );
  });

  testWidgets('a save the server refuses is said, and the words stay', (
    tester,
  ) async {
    final api = await _pump(tester, [_guest('a', 'ياسر')]);
    api.saveFails = true;

    await tester.enterText(_button('invite-free-text'), 'يا مرحبا');
    await tester.pump();
    await tester.tap(_button('invite-save'));
    await tester.pumpAndSettle();

    expect(_button('invite-save-error'), findsOneWidget);
    expect(find.text('الكلام طويل زيادة'), findsOneWidget);
    expect(find.text('يا مرحبا'), findsWidgets);
    expect(_button('invite-save'), findsOneWidget);
  });

  // The guest's occasions are in what the guest receives, each with its
  // heading, as the server writes them.
  testWidgets('the preview lists the guest\'s own occasions', (tester) async {
    final events = _Events(
      const PlanEvent(id: 'e-wedding', type: PlanEventType.wedding),
      others: const [
        PlanEvent(
          id: 'e-maqeel',
          type: PlanEventType.maqeel,
          slot: PlanEventSlot.afterAsr,
          placeLabel: 'بيت العريس',
        ),
        PlanEvent(id: 'e-lunch', type: PlanEventType.lunch),
      ],
    )..arrive();
    await _pump(tester, [
      _guest('a', 'ياسر', eventIds: const ['e-maqeel']),
    ], events: events);

    final message = _message(tester);
    expect(
      message,
      contains('*المقيل*\nالموعد: بعد العصر\nالمكان: بيت العريس'),
    );
    expect(message, contains('نرجو تأكيد حضورك لكل مناسبة من الرابط:'));
    expect(message, isNot(contains('الغداء')));

    // The page the link opens lists them too.
    await tester.tap(find.text('صفحة الدعوة'));
    await tester.pumpAndSettle();
    expect(find.text('مثال: صفحة ياسر لما يفتح الرابط'), findsOneWidget);
    expect(find.text('بيت العريس'), findsWidgets);
    expect(find.textContaining('الغداء'), findsNothing);
  });
}
