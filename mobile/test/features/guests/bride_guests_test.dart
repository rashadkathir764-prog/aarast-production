import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invitations.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/guests/utils/guest_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The bride's guests (bride_profile/out e01, e04, e07): her guests are
// women, so «الضيفات», «مدعوة», «أكدن», «ما ردّن», and her invitation is
// sent by a woman to her women guests (JOURNEY_PROFILE.md).

Guest _guest(
  String id,
  String name,
  String status, {
  String invitation = 'SENT',
  String? phone = '+967777000123',
}) => Guest(
  id: id,
  weddingPlanId: 'plan-1',
  name: name,
  phone: phone,
  side: 'BRIDE',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: invitation,
  seatsCount: 1,
  companionsCount: 0,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  // D116: what was told is the record of sends; an invitation sent named
  // the wedding (the id the server gives a plan's unsaved wedding row).
  told: [
    if (invitation == 'SENT')
      GuestToldOccasion(
        planEventId: 'wedding_plan-1',
        version: 1,
        at: DateTime(2026, 10, 2),
      ),
  ],
);

Future<void> _pumpList(
  WidgetTester tester,
  JourneyProfile profile, {
  List<Guest>? guests,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(384, 1200);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  final api = _Api(
    apiClient,
    guests ??
        [
          _guest('g1', 'عبير الحمدي', 'CONFIRMED'),
          _guest('g2', 'هدى السنيدار', 'INVITED'),
        ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
      ],
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: profile,
          child: const GuestListScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('her guest words are feminine, his stay as they are', () {
    const her = GuestWords(JourneyProfile.bride);
    const his = GuestWords(JourneyProfile.groom);
    expect(her.guests, 'الضيفات');
    expect(her.confirmed, 'أكدن');
    expect(her.pending, 'ما ردّن');
    expect(her.count(1), 'ضيفة وحدة');
    expect(his.guests, 'الضيوف');
    expect(his.confirmed, 'أكدوا');
    expect(his.count(1), 'ضيف واحد');
    final pending = _guest('g', 'هدى', 'INVITED');
    expect(guestReplyLabel(pending, JourneyProfile.bride), 'ما ردّت');
    expect(guestReplyLabel(pending, JourneyProfile.groom), 'ما ردّ');
  });

  // e04: her invitation text («تتشرف أم سلمى بدعوتكن») is the server's
  // (D83), proven in backend/test/guest-rsvp.test.ts; the card preview here
  // keeps her forms.
  test('e04: her card speaks as a woman to women guests', () {
    // Changed on purpose (D116): the removed GuestInviteCard's forms → the server text twin's host phrase.
    expect(
      invitationHostPhrase('أم سلمى', bride: true),
      'تتشرف أم سلمى بدعوتكن لحضور',
    );
    expect(
      invitationHostPhrase('أبو سالم', bride: false),
      'يتشرف أبو سالم بدعوتكم لحضور',
    );
    expect(invitationHostPhrase('  ', bride: true), isNull);
  });

  testWidgets('e01: her list is «الضيفات» with «مدعوة · أكدن · ما ردّن»', (
    tester,
  ) async {
    await _pumpList(tester, JourneyProfile.bride);

    expect(find.text('الضيفات'), findsOneWidget);
    expect(find.text('2 مدعوة · 1 أكدن · 1 ما ردّن'), findsOneWidget);
    expect(find.text('أكدن من 2'), findsOneWidget);
    expect(find.text('الضيوف'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // R17: a reminder cannot reach someone who was never invited, so the main
  // button must not promise one.
  testWidgets('guests never invited are invited, not reminded', (tester) async {
    await _pumpList(
      tester,
      JourneyProfile.bride,
      guests: [_guest('g1', 'هدى', 'INVITED', invitation: 'NOT_SENT')],
    );

    // Changed on purpose (D116): guests-invite-now «أرسلي الدعوة على واتساب» → the summary's one send action guests-send-new.
    expect(find.byKey(const ValueKey('guests-send-remind')), findsNothing);
    expect(find.byKey(const ValueKey('guests-send-new')), findsOneWidget);
    expect(find.text('أرسلي الدعوة لـضيفة وحدة'), findsOneWidget);
  });

  testWidgets('the reminder counts only who was invited', (tester) async {
    await _pumpList(
      tester,
      JourneyProfile.bride,
      guests: [
        _guest('g1', 'هدى', 'INVITED'),
        _guest('g2', 'أسماء', 'INVITED'),
        _guest('g3', 'عبلة', 'INVITED', invitation: 'NOT_SENT'),
        _guest('g4', 'سلوى', 'INVITED', phone: null),
      ],
    );

    // Changed on purpose (D116): «ذكّري الـ 2 على واتساب» → the send due first: the one never told is invited before anyone is reminded.
    expect(find.text('أرسلي الدعوة لـضيفة وحدة'), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-send-remind')), findsNothing);
  });

  testWidgets('with everyone told, the reminder counts the silent ones', (
    tester,
  ) async {
    await _pumpList(
      tester,
      JourneyProfile.bride,
      guests: [
        _guest('g1', 'هدى', 'INVITED'),
        _guest('g2', 'أسماء', 'INVITED'),
        _guest('g3', 'عبلة', 'CONFIRMED'),
        // RA-MO-61: the button counts who a reminder reaches; who has no
        // number is named on the send screen instead.
        _guest('g4', 'سلوى', 'INVITED', phone: null),
      ],
    );

    expect(find.byKey(const ValueKey('guests-send-remind')), findsOneWidget);
    expect(find.text('ذكّري ضيفتين'), findsOneWidget);
  });

  testWidgets('e01: the reminder sits in the summary card, the bar is drawn', (
    tester,
  ) async {
    await _pumpList(tester, JourneyProfile.bride);

    final card = find.ancestor(
      of: find.byKey(const ValueKey('guests-summary')),
      matching: find.byType(JourneyBox),
    );
    // Changed on purpose (D116): guests-remind «ذكّري ضيفة وحدة على واتساب» → the card's one send action guests-send-remind.
    expect(
      find.descendant(
        of: card.first,
        matching: find.byKey(const ValueKey('guests-send-remind')),
      ),
      findsOneWidget,
    );
    expect(find.text('ذكّري ضيفة وحدة'), findsOneWidget);
    // Changed on purpose (D116): the two-colour guests-summary-bar → one bar of who confirmed of who is invited.
    final bar = tester.widget<JourneyBar>(
      find.descendant(
        of: find.byKey(const ValueKey('guests-summary')),
        matching: find.byType(JourneyBar),
      ),
    );
    expect(bar.value, 0.5);
    expect(
      tester.getSize(find.byKey(const ValueKey('guests-summary'))).height,
      greaterThan(40),
    );
  });

  testWidgets('the groom keeps «الضيوف» and «أكدوا»', (tester) async {
    await _pumpList(tester, JourneyProfile.groom);

    expect(find.text('الضيوف'), findsOneWidget);
    expect(find.text('2 مدعو · 1 أكدوا · 1 ما ردّوا'), findsOneWidget);
  });
}

class _Api extends GuestsApi {
  _Api(super.apiClient, this.guests);

  final List<Guest> guests;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];
}
