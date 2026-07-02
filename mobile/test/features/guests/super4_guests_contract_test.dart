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
    expect(summary.bySideForSuper['groom'], 1);
    expect(summary.bySideForSuper['bride'], 1);
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
    expect(
      find.text(
        'نظّم الحضور والردود من بيانات حقيقية، بدون افتراض إرسال دعوات أو مشاركة لم تتم بعد.',
      ),
      findsWidgets,
    );
    expect(find.text('الضيوف'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('محمد علي'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('محمد علي'), findsOneWidget);
    expect(find.text('ليلى سالم'), findsOneWidget);
    expect(find.text('+967 777 123 456'), findsOneWidget);
    expect(find.text('تخطيط محلي'), findsOneWidget);
    expect(find.text('ضيوف يحتاجون إكمال بيانات'), findsOneWidget);
    expect(find.text('تم إرسال الدعوة'), findsNothing);
    expect(find.text('مشارك في الخطة'), findsNothing);
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
    expect(find.text('ضيوف بدون رقم جوال'), findsOneWidget);

    await tester.tap(find.text('ضيوف يحتاجون إكمال بيانات'));
    await tester.pumpAndSettle();

    expect(find.text('ناقص بيانات'), findsWidgets);
    expect(find.text('ضيف بدون رقم'), findsOneWidget);
    expect(find.text('ضيف مكتمل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Guest works without login for local plan', (tester) async {
    _setPhoneView(tester, height: 1600);
    final harness = await _createHarness();
    final provider = GuestsProvider(harness.api);

    await tester.pumpWidget(_providers(harness, provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_textFieldWithLabel('اسم الضيف'), 'سالم أحمد');
    await tester.enterText(
      _textFieldWithLabel('رقم الجوال (اختياري)'),
      '777654321',
    );
    final submit = find.widgetWithText(FilledButton, 'إضافة ضيف').last;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(provider.guests, hasLength(1));
    expect(provider.guests.single.name, 'سالم أحمد');
    expect(provider.guests.single.phone, '+967777654321');
    expect(find.text('سالم أحمد'), findsOneWidget);
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

    await _pumpGuestsScreen(tester, harness, setView: false);

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
}) async {
  if (setView) _setPhoneView(tester);
  await tester.pumpWidget(_providers(harness, GuestsProvider(harness.api)));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Widget _providers(_Harness harness, GuestsProvider provider) {
  return MultiProvider(
    providers: [
      Provider<AuthStorage>.value(value: harness.authStorage),
      ChangeNotifierProvider<OfflineSyncService>.value(value: harness.offline),
      ChangeNotifierProvider<GuestsProvider>.value(value: provider),
    ],
    child: const MaterialApp(
      themeMode: ThemeMode.light,
      home: GuestListScreen(weddingPlanId: _localPlanId),
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

Finder _textFieldWithLabel(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(TextField))
      .first;
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
