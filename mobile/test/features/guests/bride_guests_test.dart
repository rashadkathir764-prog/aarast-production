import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
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

Guest _guest(String id, String name, String status) => Guest(
  id: id,
  weddingPlanId: 'plan-1',
  name: name,
  side: 'BRIDE',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: 'SENT',
  seatsCount: 1,
  companionsCount: 0,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

Future<void> _pumpList(WidgetTester tester, JourneyProfile profile) async {
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
  final api = _Api(apiClient, [
    _guest('g1', 'عبير الحمدي', 'CONFIRMED'),
    _guest('g2', 'هدى السنيدار', 'INVITED'),
  ]);
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

  test('e04: her invitation is in her mother\'s name to women guests', () {
    final text = guestInviteMessage(
      const GuestInviteCard(
        title: 'زفة سلمى',
        host: 'أم سلمى',
        profile: JourneyProfile.bride,
      ),
      guestName: 'أسماء',
      url: 'aarast.app/rsvp/x',
    );
    expect(text, contains('تتشرف أم سلمى بدعوتكن'));
    expect(text, contains('أكّدي حضورك'));
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

  testWidgets('e01: the reminder sits in the summary card, the bar is drawn', (
    tester,
  ) async {
    await _pumpList(tester, JourneyProfile.bride);

    final card = find.ancestor(
      of: find.byKey(const ValueKey('guests-summary')),
      matching: find.byType(JourneyBox),
    );
    expect(
      find.descendant(
        of: card.first,
        matching: find.byKey(const ValueKey('guests-remind')),
      ),
      findsOneWidget,
    );
    expect(find.text('ذكّري الـ 1 على واتساب'), findsOneWidget);
    // The confirmed and waiting pieces are 10 high, not collapsed.
    final pieces = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('guests-summary-bar')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(pieces.map((piece) => piece.color), [
      AarastV3Color.rose,
      AarastV3Color.saffron,
    ]);
    final shown = find.descendant(
      of: find.byKey(const ValueKey('guests-summary-bar')),
      matching: find.byType(ColoredBox),
    );
    for (final element in shown.evaluate()) {
      expect(element.size!.height, 10);
    }
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
