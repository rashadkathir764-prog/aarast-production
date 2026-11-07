import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_import.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_import_screen.dart';
import 'package:aarast_mobile/shared/models/contact_phone_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// e03 from the contacts and w28 a pasted list: many guests in one go,
// whoever the plan already has marked and never added twice.

Guest _guest(String id, String name, {String? phone}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: id,
    weddingPlanId: 'plan-1',
    name: name,
    phone: phone,
    side: 'OTHER',
    status: 'INVITED',
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class _Api extends GuestsApi {
  _Api(this.guests, {this.groups = const []})
    : super(ApiClient(tokenProvider: () async => null));

  final List<Guest> guests;
  final List<GuestGroup> groups;
  final sent = <({String name, String? phone})>[];
  String? sentGroupId;
  Set<String> refuseNames = const {};

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => groups;

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: guests);

  @override
  Future<
    ({
      List<Guest> created,
      List<({String name, String? phone})> refused,
      String? reason,
    })
  >
  createGuestsBulk({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    sent.addAll(people);
    sentGroupId = groupId;
    // RA-MO-34: the server refuses the people named in [refuseNames].
    final added = [
      for (final person in people)
        if (!refuseNames.contains(person.name)) person,
    ];
    return (
      created: [
        for (var i = 0; i < added.length; i++)
          _guest('new-$i', added[i].name, phone: added[i].phone),
      ],
      refused: [
        for (final person in people)
          if (refuseNames.contains(person.name)) person,
      ],
      reason: refuseNames.isEmpty ? null : 'هذا الضيف مضاف مسبقًا',
    );
  }
}

Future<_Api> _pump(
  WidgetTester tester, {
  required GuestImportSource source,
  List<Guest> guests = const [],
  List<GuestGroup> groups = const [],
  List<ContactPhoneDraft> contacts = const [],
  Set<String> refuseNames = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'aarast_access_token': 'token'});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final api = _Api(guests, groups: groups)..refuseNames = refuseNames;
  final provider = GuestsProvider(api);
  await provider.loadGuests('plan-1');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: storage),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
      ],
      child: MaterialApp.router(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        routerConfig: GoRouter(
          initialLocation: '/import',
          routes: [
            GoRoute(
              path: '/import',
              builder: (context, state) => GuestImportScreen(
                weddingPlanId: 'plan-1',
                source: source,
                loadContacts: () async => contacts,
              ),
            ),
            GoRoute(
              path: '/wedding-plans/:id/guests',
              builder: (context, state) => const Text('قائمة الضيوف'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

final _add = find.byKey(const ValueKey('import-add'));

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.ensureVisible(_add);
  await tester.tap(_add);
  await tester.pumpAndSettle();
}

void main() {
  group('reading a pasted list', () {
    test('takes the name and an optional number in any place', () {
      final people = parseGuestLines(
        'عبدالله الحمدي 771 234 567\n'
        '\n'
        'يحيى السنيدار\n'
        '٧٧٣٤٥٦٧٨٩ - أحمد ناجي\n'
        '   \n'
        '777123456',
      );
      expect(people, [
        (name: 'عبدالله الحمدي', phone: '771234567'),
        (name: 'يحيى السنيدار', phone: null),
        (name: 'أحمد ناجي', phone: '773456789'),
      ]);
    });

    // RA-BE-15/16: a name the server would refuse held the queued import as
    // «السيرفر رفضه»; it stops at the server's 120, counted as the phone and
    // the server both count (a letter with its marks is one).
    test(
      'a name longer than the server takes is cut, counted by character',
      () {
        final long = 'مُحَمَّد ' * 30; // 30 names of 4 characters and a space.
        final [candidate] = markGuestCandidates([
          (name: long, phone: null),
        ], []);
        expect(candidate.name.characters.length, lessThanOrEqualTo(120));
        expect(candidate.name.characters.length, greaterThan(110));
        expect(candidate.name, startsWith('مُحَمَّد'));
        // A name inside the limit is kept whole.
        final [short] = markGuestCandidates([
          (name: 'مُحَمَّد علي', phone: null),
        ], []);
        expect(short.name, 'مُحَمَّد علي');
      },
    );

    test('marks who the plan has and who repeats in the list', () {
      final candidates = markGuestCandidates(
        [
          (name: 'أحمد', phone: '777123456'),
          (name: 'سالم', phone: null),
          (name: 'سالم', phone: null),
          (name: 'علي', phone: '771000000'),
          (name: 'علي ثاني', phone: '+967 771000000'),
          (name: 'خالد', phone: '123'),
        ],
        [_guest('g1', 'أحمد ناجي', phone: '+967777123456')],
      );
      expect(candidates[0].existing?.id, 'g1');
      expect(candidates[1].isDuplicate, isFalse);
      expect(candidates[2].repeated, isTrue);
      expect(candidates[3].isDuplicate, isFalse);
      expect(candidates[3].phone, '+967771000000');
      expect(candidates[4].repeated, isTrue);
      // A wrong number does not fail the list: the guest goes in without it.
      expect(candidates[5].phone, isNull);
      expect(candidates[5].badPhone, '123');
      expect(candidates[5].isDuplicate, isFalse);
    });

    test('groups contacts by family when two or more share it', () {
      final sections = groupByFamily([
        'عبدالله الحمدي',
        'صالح الحمدي',
        'محمد',
        'يحيى السنيدار',
      ]);
      expect(sections.first.family, 'آل الحمدي');
      expect(sections.first.members, [0, 1]);
      expect(sections.last.family, isNull);
      expect(sections.last.members, [2, 3]);
    });
  });

  testWidgets('w28 adds the new lines and skips who is already there', (
    tester,
  ) async {
    const group = GuestGroup(
      id: 'g-hara',
      weddingPlanId: 'plan-1',
      name: 'الحارة',
    );
    final api = await _pump(
      tester,
      source: GuestImportSource.paste,
      guests: [_guest('g1', 'أحمد ناجي', phone: '+967777123456')],
      groups: const [group],
    );
    expect(find.text('أضف مجموعة ضيوف'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('import-paste')).hitTestable().first,
      'عبدالله الحمدي 771234567\nيحيى السنيدار\nأحمد ناجي 777123456',
    );
    await tester.pumpAndSettle();

    expect(find.text('فهمناها كذا'), findsOneWidget);
    expect(find.text('بدون رقم'), findsOneWidget);
    expect(find.text('موجود من قبل · ما نضيفه مرتين'), findsOneWidget);
    expect(find.text('أضف ضيفين'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-group-g-hara')));
    await tester.pumpAndSettle();
    await _tapAdd(tester);

    expect(api.sent, [
      (name: 'عبدالله الحمدي', phone: '+967771234567'),
      (name: 'يحيى السنيدار', phone: null),
    ]);
    expect(api.sentGroupId, 'g-hara');
    expect(find.text('قائمة الضيوف'), findsOneWidget);
  });

  // RA-MO-34: one refused line said «ما قدرنا نضيف الضيوف» over the guests it
  // had added, and adding again added them twice. The added ones stay, the
  // page says what did not go and why, and a retry sends only that one.
  testWidgets(
    'a line the server refuses keeps the others and is the only one retried',
    (tester) async {
      final api = await _pump(
        tester,
        source: GuestImportSource.paste,
        refuseNames: {'يحيى السنيدار'},
      );
      await tester.enterText(
        find.byKey(const ValueKey('import-paste')).hitTestable().first,
        'عبدالله الحمدي 771234567\nيحيى السنيدار 772222222',
      );
      await tester.pumpAndSettle();
      await _tapAdd(tester);

      expect(find.textContaining('انضاف 1، وما انضاف 1'), findsOneWidget);
      expect(find.text('قائمة الضيوف'), findsNothing);
      expect(find.text('موجود من قبل · ما نضيفه مرتين'), findsOneWidget);

      api.sent.clear();
      await _tapAdd(tester);
      expect(api.sent, [(name: 'يحيى السنيدار', phone: '+967772222222')]);
    },
  );

  testWidgets('e03 ticks contacts, a whole family at once, never a duplicate', (
    tester,
  ) async {
    ContactPhoneDraft contact(String name, String phone) =>
        ContactPhoneDraft.fromInput(name: name, rawPhone: phone);
    final api = await _pump(
      tester,
      source: GuestImportSource.contacts,
      guests: [_guest('g1', 'صالح', phone: '+967777000002')],
      contacts: [
        contact('عبدالله الحمدي', '777000001'),
        contact('صالح الحمدي', '777000002'),
        contact('محمد الحمدي', '777000003'),
        contact('علي', '777000004'),
      ],
    );

    expect(find.text('آل الحمدي · 3 من جهاتك'), findsOneWidget);
    expect(find.text('الباقين'), findsOneWidget);
    expect(find.text('أضف'), findsOneWidget);

    await tester.tap(find.text('اختر الكل').first);
    await tester.pumpAndSettle();
    expect(find.text('أضف ضيفين'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-contact-3')));
    await tester.pumpAndSettle();
    // The duplicate cannot be ticked.
    await tester.tap(find.byKey(const ValueKey('import-contact-1')));
    await tester.pumpAndSettle();
    expect(find.text('أضف 3 ضيوف'), findsOneWidget);

    await _tapAdd(tester);
    expect(api.sent.map((person) => person.name), [
      'عبدالله الحمدي',
      'محمد الحمدي',
      'علي',
    ]);
  });

  testWidgets('e03 says plainly when contacts cannot be read', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    final provider = GuestsProvider(_Api(const []));
    var calls = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<GuestsProvider>.value(
        value: provider,
        child: MaterialApp(
          home: GuestImportScreen(
            weddingPlanId: 'plan-1',
            source: GuestImportSource.contacts,
            loadContacts: () async {
              calls++;
              throw StateError('no plugin');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-error')), findsOneWidget);
    expect(find.text('ما قدرنا نقرأ جهات الاتصال'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
