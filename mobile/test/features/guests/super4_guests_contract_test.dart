import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localPlanId = 'guest-plan-super4';

void main() {
  test('guest summary model parses accepted Super 4 backend aliases', () {
    final summary = GuestSummary.fromJson({
      'weddingPlanId': 'plan-1',
      'totalGuests': 5,
      'confirmedGuests': 2,
      'pending': 2,
      'declined': 1,
      'notAttending': 1,
      'missingPhoneCount': 1,
      'missingNameCount': 0,
      'incompleteGuestsCount': 1,
      'expectedSeatsCount': 8,
      'companionsExpectedCount': 3,
      'groupsCount': 2,
      'bySideForSuper': {'groom': 2, 'bride': 2, 'unknown': 1},
      'byGroup': {'العائلة': 3, 'الأصدقاء': 2},
    });

    expect(summary.totalGuests, 5);
    expect(summary.confirmed, 2);
    expect(summary.pending, 2);
    expect(summary.declined, 1);
    expect(summary.missingPhoneCount, 1);
    expect(summary.incompleteGuestsCount, 1);
    expect(summary.expectedSeatsCount, 8);
    expect(summary.companionsExpectedCount, 3);
    expect(summary.bySideForSuper['groom'], 2);
    expect(summary.byGroup['العائلة'], 3);
  });

  test('local guest summary updates total confirmed incomplete and sides', () {
    final summary = GuestSummary.fromGuests(
      weddingPlanId: _localPlanId,
      guests: [
        _guest(
          id: 'confirmed',
          name: 'محمد علي',
          phone: '+967777123456',
          side: 'GROOM',
          status: 'CONFIRMED',
          attendanceStatus: 'CONFIRMED',
          seatsCount: 3,
          companionsCount: 2,
        ),
        _guest(id: 'missing-phone', name: 'ليلى سالم', side: 'BRIDE'),
      ],
    );

    expect(summary.totalGuests, 2);
    expect(summary.confirmed, 1);
    expect(summary.pending, 1);
    expect(summary.incompleteGuestsCount, 1);
    expect(summary.expectedSeatsCount, 4);
    expect(summary.companionsExpectedCount, 2);
    // RA-MO-59: only the confirmed one and his two companions.
    expect(summary.confirmedSeatsCount, 3);
    expect(summary.bySideForSuper['groom'], 1);
    expect(summary.bySideForSuper['bride'], 1);
  });

  test('guests added in the same instant on a phone plan all stay', () async {
    final harness = await _createHarness();
    for (var index = 0; index < 20; index++) {
      await harness.api.createGuest(
        weddingPlanId: _localPlanId,
        name: 'ضيف $index',
        side: 'GROOM',
        status: 'INVITED',
        seatsCount: 1,
      );
    }
    final guests = await harness.api.getGuests(_localPlanId);
    expect(guests, hasLength(20));
    expect(guests.map((guest) => guest.id).toSet(), hasLength(20));
  });

  testWidgets('approved guest UI counts seats once when companions exist', (
    tester,
  ) async {
    _setPhoneView(tester, height: 900);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'محمد علي',
      phone: '777123456',
      side: 'GROOM',
      status: 'CONFIRMED',
      attendanceStatus: 'CONFIRMED',
      seatsCount: 3,
      companionsCount: 2,
    );
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'ليلى سالم',
      phone: '777654321',
      side: 'BRIDE',
      status: 'PENDING',
      seatsCount: 1,
    );

    await _pumpGuestsScreen(tester, harness, setView: false);

    // e01: one confirmed guest, with his two companions counted once.
    // RA-MO-219 (2026-11-13): no invitation went to Laila yet, so she is not
    // counted as «ما ردّوا».
    expect(find.text('2 مدعو · 1 أكدوا · 1 بلا دعوة'), findsOneWidget);
    expect(find.text('أكدوا من 2'), findsOneWidget);
    // RA-MO-59: the confirmed and who comes with them, not the one who has
    // not replied (3 to 10 take the plural, arabicSeats).
    expect(find.text('مع المرافقين: 3 مقاعد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // R10: nobody confirmed yet is not a number worth saying.
  testWidgets('the status line skips «0 أكدوا»', (tester) async {
    _setPhoneView(tester, height: 900);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'ليلى سالم',
      phone: '777654321',
      side: 'BRIDE',
      status: 'PENDING',
      seatsCount: 1,
    );

    await _pumpGuestsScreen(tester, harness, setView: false);

    // RA-MO-219: no invitation went yet.
    expect(find.text('1 مدعو · 1 بلا دعوة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local guest appears in Super 4 Guests screen without login', (
    tester,
  ) async {
    _setPhoneView(tester);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'محمد علي',
      phone: '777123456',
      side: 'GROOM',
      status: 'CONFIRMED',
      attendanceStatus: 'CONFIRMED',
      seatsCount: 2,
      companionsCount: 1,
    );
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'ليلى سالم',
      side: 'BRIDE',
      status: 'INVITED',
      seatsCount: 1,
    );

    await _pumpGuestsScreen(tester, harness);

    expect(find.text('الضيوف'), findsWidgets);
    expect(find.byKey(const ValueKey('guests-summary')), findsOneWidget);
    // A phone-only plan has no groups to manage.
    expect(find.text('المجموعات'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();

    expect(find.text('محمد علي'), findsOneWidget);
    expect(find.text('ليلى سالم'), findsOneWidget);
    expect(find.text('أكّد مع 1'), findsOneWidget);
    expect(find.text('ما وصلته دعوة'), findsOneWidget);
    expect(find.text('طلب عرض سعر'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing phone guest appears in Important Now and filter', (
    tester,
  ) async {
    _setPhoneView(tester);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'ضيف مكتمل',
      phone: '777123456',
      side: 'GROOM',
      status: 'CONFIRMED',
      attendanceStatus: 'CONFIRMED',
      seatsCount: 1,
    );
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'ضيف بدون رقم',
      side: 'BRIDE',
      status: 'PENDING',
      seatsCount: 1,
    );

    await _pumpGuestsScreen(tester, harness);
    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();
    expect(find.textContaining('بدون رقم'), findsWidgets);

    final noPhone = find.byKey(const ValueKey('guest-filter-noPhone'));
    await tester.ensureVisible(noPhone);
    await tester.pumpAndSettle();
    await tester.tap(noPhone);
    await tester.pumpAndSettle();

    expect(find.text('ضيف بدون رقم'), findsOneWidget);
    expect(find.text('ضيف مكتمل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search finds a guest by name or number', (tester) async {
    _setPhoneView(tester);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'عبدالله الحمدي',
      phone: '771234567',
      side: 'GROOM',
      status: 'INVITED',
      seatsCount: 1,
    );
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'يحيى السنيدار',
      side: 'GROOM',
      status: 'INVITED',
      seatsCount: 1,
    );

    await _pumpGuestsScreen(tester, harness);
    await tester.tap(find.byKey(const ValueKey('guests-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('guests-search-field')),
      '1234',
    );
    await tester.pumpAndSettle();

    expect(find.text('عبدالله الحمدي'), findsOneWidget);
    expect(find.text('يحيى السنيدار'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Guest works without login for local plan', (tester) async {
    _setPhoneView(tester, height: 1600);
    final harness = await _createHarness();
    final provider = GuestsProvider(harness.api);

    await tester.pumpWidget(_providers(harness, provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guests-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('guest-form-name')),
      'سالم أحمد',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('guest-form-phone')),
        matching: find.byType(EditableText),
      ),
      '777654321',
    );
    final submit = find.byKey(const ValueKey('guest-form-save'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(provider.guests, hasLength(1));
    expect(provider.guests.single.name, 'سالم أحمد');
    expect(provider.guests.single.phone, '+967777654321');
    expect(find.textContaining('1 مدعو'), findsOneWidget);
    expect(find.text('هذه الخطوة تحتاج حسابًا'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super 4 Guests screen has no overflow at 320px', (tester) async {
    _setPhoneView(tester, width: 320, height: 1600);
    final harness = await _createHarness();
    await harness.api.createGuest(
      weddingPlanId: _localPlanId,
      name: 'اسم ضيف طويل جدًا لاختبار عرض الهاتف الصغير بدون تجاوز مرئي',
      phone: '777123456',
      side: 'GROOM',
      status: 'PENDING',
      seatsCount: 3,
      companionsCount: 2,
      notes: 'ملاحظة طويلة للتأكد من أن البطاقة لا تضغط العناصر في عرض ضيق.',
    );

    await _pumpGuestsScreen(tester, harness, setView: false, textScale: 1.3);

    expect(find.text('الضيوف'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Guest _guest({
  required String id,
  required String name,
  String? phone,
  String side = 'OTHER',
  String status = 'INVITED',
  String attendanceStatus = 'PENDING',
  int seatsCount = 1,
  int companionsCount = 0,
}) {
  return Guest(
    id: id,
    weddingPlanId: _localPlanId,
    name: name,
    phone: phone,
    side: side,
    status: status,
    attendanceStatus: attendanceStatus,
    invitationStatus: 'NOT_SENT',
    seatsCount: seatsCount,
    companionsCount: companionsCount,
    createdAt: DateTime(2026, 6, 28),
    updatedAt: DateTime(2026, 6, 28),
  );
}

Future<_Harness> _createHarness() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  return _Harness(
    authStorage: authStorage,
    apiClient: apiClient,
    offline: offline,
    api: GuestsApi(apiClient, offline: offline),
  );
}

Future<void> _pumpGuestsScreen(
  WidgetTester tester,
  _Harness harness, {
  bool setView = true,
  double textScale = 1,
}) async {
  if (setView) _setPhoneView(tester);
  await tester.pumpWidget(
    _providers(harness, GuestsProvider(harness.api), textScale: textScale),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  // The saved list loads asynchronously; wait until it is on screen.
  await tester.pumpAndSettle();
}

Widget _providers(
  _Harness harness,
  GuestsProvider provider, {
  double textScale = 1,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthStorage>.value(value: harness.authStorage),
      ChangeNotifierProvider<OfflineSyncService>.value(value: harness.offline),
      ChangeNotifierProvider<GuestsProvider>.value(value: provider),
    ],
    child: MaterialApp(
      themeMode: ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const GuestListScreen(weddingPlanId: _localPlanId),
    ),
  );
}

void _setPhoneView(
  WidgetTester tester, {
  double width = 390,
  double height = 1400,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

class _Harness {
  const _Harness({
    required this.authStorage,
    required this.apiClient,
    required this.offline,
    required this.api,
  });

  final AuthStorage authStorage;
  final ApiClient apiClient;
  final OfflineSyncService offline;
  final GuestsApi api;
}
