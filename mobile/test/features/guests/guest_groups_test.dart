import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_groups_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuestsProvider groups', () {
    late _GroupsApi api;
    late GuestsProvider provider;

    setUp(() async {
      api = _GroupsApi();
      provider = GuestsProvider(api);
      await provider.loadGuests('plan-1');
    });

    test('create and rename show the saved groups', () async {
      expect(await provider.createGroup('plan-1', 'الأصدقاء'), isTrue);
      final created = provider.groups.last;
      expect(created.name, 'الأصدقاء');

      expect(await provider.renameGroup(created, 'أصدقاء العمل'), isTrue);
      expect(provider.groups.last.name, 'أصدقاء العمل');
      expect(provider.groupsErrorMessage, isNull);
    });

    test('deleting a group keeps its guests without a group', () async {
      final family = provider.groups.single;

      expect(await provider.deleteGroup(family), isTrue);

      expect(provider.groups, isEmpty);
      expect(provider.guests, hasLength(1));
      expect(provider.guests.single.groupId, isNull);
    });

    // RA-MO-227: an unsent group deleted left its guests' queued changes
    // naming it, refused by the server and stuck.
    test('an unsent group with guests is not deleted, and says why', () async {
      final offlineApi = _GroupsApi()..familyId = 'queued-guest_group-1';
      final offline = GuestsProvider(offlineApi);
      await offline.loadGuests('plan-1');

      expect(await offline.deleteGroup(offline.groups.single), isFalse);

      expect(offlineApi.deletes, 0);
      expect(offline.groups, hasLength(1));
      expect(offline.groupsErrorMessage, contains('ما وصلت بعد وفيها ضيوف'));
    });

    test('a rejected change keeps the groups and says why', () async {
      api.reject = true;

      expect(await provider.createGroup('plan-1', 'الأصدقاء'), isFalse);

      expect(provider.groups.map((group) => group.name), ['الأهل']);
      expect(provider.groupsErrorMessage, 'لا تملك صلاحية إدارة الضيوف.');
      expect(provider.isSavingGroups, isFalse);

      // RA-MO-234: opened again, the sheet does not carry that old error.
      provider.clearGroupsError();
      expect(provider.groupsErrorMessage, isNull);
    });
  });

  testWidgets(
    'the sheet adds, renames and deletes groups with a clear warning',
    (tester) async {
      final created = <String>[];
      final renamed = <String>[];
      final deleted = <String>[];
      const family = GuestGroup(
        id: 'family',
        weddingPlanId: 'plan-1',
        name: 'الأهل',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuestGroupsSheet(
              groups: const [family],
              guestCounts: const {'family': 3},
              saving: false,
              onCreate: (name) async {
                created.add(name);
                return true;
              },
              onRename: (group, name) async {
                renamed.add('${group.id}:$name');
                return true;
              },
              onDelete: (group) async {
                deleted.add(group.id);
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('3 ضيوف'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('guest-group-new-name')),
        'الأصدقاء',
      );
      await tester.tap(find.byKey(const ValueKey('guest-group-add')));
      await tester.pumpAndSettle();
      expect(created, ['الأصدقاء']);

      await tester.tap(find.text('الأهل'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('guest-group-rename-field')),
        'أهل العريس',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(renamed, ['family:أهل العريس']);

      await tester.tap(find.byTooltip('شيل مجموعة الأهل'));
      await tester.pumpAndSettle();
      expect(
        find.text('ضيوفها (3) يبقون في قائمتك بدون مجموعة.'),
        findsOneWidget,
      );
      await tester.tap(find.text('شيل المجموعة'));
      await tester.pumpAndSettle();
      expect(deleted, ['family']);
      expect(tester.takeException(), isNull);
    },
  );
}

class _GroupsApi extends GuestsApi {
  _GroupsApi() : super(ApiClient(tokenProvider: () async => null));

  bool reject = false;
  int _sequence = 0;
  int deletes = 0;

  /// The family's id: a «queued-» one was made on the phone and not sent.
  String familyId = 'family';

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => [
    Guest(
      id: 'guest-1',
      weddingPlanId: weddingPlanId,
      groupId: familyId,
      name: 'خالد',
      side: 'GROOM',
      status: 'INVITED',
      seatsCount: 1,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => [
    GuestGroup(id: familyId, weddingPlanId: weddingPlanId, name: 'الأهل'),
  ];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: localGuests ?? const [],
    groups: localGroups ?? const [],
  );

  void _gate() {
    if (reject) {
      throw const ApiException('لا تملك صلاحية إدارة الضيوف.', statusCode: 403);
    }
  }

  @override
  Future<GuestGroup> createGroup({
    required String weddingPlanId,
    required String name,
  }) async {
    _gate();
    _sequence += 1;
    return GuestGroup(
      id: 'group-$_sequence',
      weddingPlanId: weddingPlanId,
      name: name,
    );
  }

  @override
  Future<GuestGroup> renameGroup(GuestGroup group, String name) async {
    _gate();
    return GuestGroup(
      id: group.id,
      weddingPlanId: group.weddingPlanId,
      name: name,
    );
  }

  @override
  Future<void> deleteGroup(GuestGroup group) async {
    _gate();
    deletes += 1;
  }
}
