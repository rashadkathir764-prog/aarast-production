import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_groups_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D80: a helper with the guests right reads every guest of the plan. The
// guests they added keep their controls; the groom's guests are plain rows
// (name, reply, companions) without a number, a reminder or a way in.

Guest _guest(
  String id,
  String name, {
  required bool editable,
  String status = 'INVITED',
  String? phone,
  String? groupId,
  int companions = 0,
}) => Guest(
  id: id,
  weddingPlanId: 'plan-1',
  name: name,
  side: 'GROOM',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: 'SENT',
  seatsCount: 1,
  companionsCount: companions,
  phone: phone,
  groupId: groupId,
  editable: editable,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

const _ownerGroup = GuestGroup(
  id: 'group-owner',
  weddingPlanId: 'plan-1',
  name: 'أهل العريس',
  editable: false,
);
const _ownGroup = GuestGroup(
  id: 'group-own',
  weddingPlanId: 'plan-1',
  name: 'أصحابي',
);

final _mixed = [
  _guest('own', 'سالم', editable: true, phone: '+967777000003'),
  _guest(
    'groom-1',
    'خالد',
    editable: false,
    status: 'CONFIRMED',
    companions: 2,
    groupId: _ownerGroup.id,
  ),
  _guest('groom-2', 'ناصر', editable: false, groupId: _ownerGroup.id),
];

Future<void> _pumpList(
  WidgetTester tester, {
  required List<Guest> guests,
  List<GuestGroup> groups = const [_ownerGroup, _ownGroup],
  String? ownerWord = 'العريس',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(384, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(_Api(apiClient, guests, groups)),
        ),
      ],
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: GuestListScreen(weddingPlanId: 'plan-1', ownerWord: ownerWord),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pressableAround(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(AarastPressable));

void main() {
  test('editable reads the server flag and defaults to true for older servers', () {
    final base = {
      'id': 'g1',
      'weddingPlanId': 'plan-1',
      'name': 'سالم',
      'side': 'GROOM',
      'status': 'INVITED',
    };
    expect(Guest.fromJson(base).editable, isTrue);
    expect(Guest.fromJson({...base, 'editable': true}).editable, isTrue);
    expect(Guest.fromJson({...base, 'editable': false}).editable, isFalse);
    final group = {'id': 'x', 'weddingPlanId': 'plan-1', 'name': 'الأهل'};
    expect(GuestGroup.fromJson(group).editable, isTrue);
    expect(
      GuestGroup.fromJson({...group, 'editable': false}).editable,
      isFalse,
    );
    // A guest whose number is kept by the owner is neither missing data nor
    // someone this reader can remind or invite.
    final kept = _guest('k', 'خالد', editable: false);
    expect(kept.hasMissingData, isFalse);
    expect(kept.canBeReminded, isFalse);
    expect(kept.awaitsInvitation, isFalse);
    expect(kept.withoutGroup().editable, isFalse);
  });

  testWidgets('a helper sees the whole plan, controls only on their own guests', (
    tester,
  ) async {
    await _pumpList(tester, guests: _mixed);

    // The figures count the whole plan.
    expect(find.text('3 مدعو · 1 أكدوا · 2 ما ردّوا'), findsOneWidget);
    expect(find.text('أكدوا من 3'), findsOneWidget);
    // Only the helper's own waiting guest can be reminded from here.
    expect(find.text('ذكّر ضيف واحد على واتساب'), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-helper-note')), findsOneWidget);
    expect(find.textContaining('عند العريس'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();

    expect(find.text('سالم'), findsOneWidget);
    expect(find.text('خالد'), findsOneWidget);
    expect(find.text('ناصر'), findsOneWidget);
    // Name, reply and companions for the groom's guest.
    expect(find.text('أكّد مع 2'), findsOneWidget);
    // His guests' numbers are his, not missing.
    expect(find.textContaining('بدون رقم ·'), findsNothing);
    expect(find.text('بدون رقم 0'), findsOneWidget);
    expect(find.textContaining('بدون رقم'), findsOneWidget);
    // The helper's own guest opens; the groom's guests are plain rows.
    expect(_pressableAround('سالم'), findsOneWidget);
    expect(_pressableAround('خالد'), findsNothing);
    expect(_pressableAround('ناصر'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a helper adds only to the groups they made', (tester) async {
    await _pumpList(tester, guests: _mixed);

    await tester.tap(find.byKey(const ValueKey('guests-add')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('أصحابي')),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('أهل العريس')),
      findsNothing,
    );
  });

  testWidgets('an empty plan does not tell a helper the list is theirs', (
    tester,
  ) async {
    await _pumpList(tester, guests: const [], groups: const []);

    expect(find.text('ابدأ بقائمة ضيوفك'), findsNothing);
    expect(find.textContaining('ما أضفت أحد بعد'), findsNothing);
    expect(find.text('ابدأ بقائمة الضيوف'), findsOneWidget);
    expect(find.text('ما فيه الضيوف في القائمة بعد.'), findsNothing);
    expect(find.text('ما فيه ضيوف في القائمة بعد.'), findsOneWidget);
    // The ways to add stay.
    expect(find.byKey(const ValueKey('guests-first-one')), findsOneWidget);
  });

  testWidgets('the owner\'s own list keeps its words', (tester) async {
    await _pumpList(
      tester,
      guests: const [],
      groups: const [],
      ownerWord: null,
    );

    expect(find.text('ابدأ بقائمة ضيوفك'), findsOneWidget);
    expect(find.text('ما أضفت أحد بعد.'), findsOneWidget);
  });

  testWidgets('the groups sheet renames and removes only the reader\'s groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuestGroupsSheet(
            groups: const [_ownerGroup, _ownGroup],
            guestCounts: const {},
            saving: false,
            onCreate: (_) async => true,
            onRename: (_, _) async => true,
            onDelete: (_) async => true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('شيل مجموعة أصحابي'), findsOneWidget);
    expect(find.byTooltip('شيل مجموعة أهل العريس'), findsNothing);

    await tester.tap(find.text('أهل العريس'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guest-group-rename-field')), findsNothing);
  });
}

class _Api extends GuestsApi {
  _Api(super.apiClient, this.guests, this.groups);

  final List<Guest> guests;
  final List<GuestGroup> groups;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => groups;

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: guests,
    groups: groups,
  );
}
