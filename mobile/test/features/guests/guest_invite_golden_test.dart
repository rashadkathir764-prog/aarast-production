@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_invite_screen.dart';
import 'package:aarast_mobile/features/guests/screens/guest_send_screen.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_invitation_card_image.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/preview_fonts.dart';
import '../../support/app_text_scale.dart';

// e04 / e08 as the owner sees them, with a real-sized Yemeni plan: long
// names, a long venue, three occasions, one guest without a number. Each
// golden is the whole page (the view is as tall as the page) so every
// section can be judged; the keyboard one is a real 320 × 640 phone.

const _photo = 'https://media.example/guest-invitation-card/u/card.jpg';

Guest _guest(
  String id,
  String name, {
  String? phone = '+967777000111',
  String invitationStatus = 'NOT_SENT',
  String attendanceStatus = 'PENDING',
  List<String> events = const [],
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: id,
    weddingPlanId: 'plan-1',
    name: name,
    phone: phone,
    side: 'GROOM',
    status: attendanceStatus == 'PENDING' ? 'INVITED' : attendanceStatus,
    attendanceStatus: attendanceStatus,
    invitationStatus: invitationStatus,
    seatsCount: 1,
    events: [for (final id in events) GuestEventReply(planEventId: id)],
    createdAt: now,
    updatedAt: now,
    // D116: what was told is the record of sends.
    told: [
      if (invitationStatus == 'SENT')
        GuestToldOccasion(
          planEventId: 'e-wedding',
          version: 1,
          at: DateTime(2026, 11, 1),
        ),
    ],
  );
}

final _guests = [
  _guest(
    'g1',
    'عبدالرحمن محمد عبدالله الأهدل',
    events: const ['e-samra', 'e-maqeel', 'e-lunch'],
  ),
  _guest('g2', 'صالح بن أحمد المقطري'),
  _guest('g3', 'فهد العريقي'),
  _guest('g4', 'نبيل الشرعبي', phone: null),
  _guest('g5', 'مراد الحكيمي', invitationStatus: 'SENT'),
  _guest('g7', 'سامي الوصابي', invitationStatus: 'SENT', phone: null),
  _guest(
    'g6',
    'ياسر القدسي',
    invitationStatus: 'SENT',
    attendanceStatus: 'CONFIRMED',
  ),
];

class _Api extends GuestsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => _guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: _guests);

  @override
  Future<InvitationCard> getInvitationCard(String weddingPlanId) async =>
      const InvitationCard(
        hostLine: 'عبدالرحمن بن محمد الحمدي',
        freeText: 'يا مرحبا بالحاضرين، نورتوا فرحتنا',
        photoUrl: _photo,
      );
}

class _Events extends PlanEventsProvider {
  _Events()
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  @override
  PlanEventsView? viewOf(String weddingPlanId) => PlanEventsView(
    weddingPlanId: weddingPlanId,
    canEdit: true,
    items: [
      const PlanEvent(
        id: 'e-wedding',
        type: PlanEventType.wedding,
        slot: PlanEventSlot.afterIsha,
        placeLabel: 'قاعة سبأ الكبرى للمناسبات - حدة',
        mapUrl: 'https://maps.app.goo.gl/Hadda7Sanaa',
      ),
      PlanEvent(
        id: 'e-samra',
        type: PlanEventType.samra,
        date: DateTime(2027, 2, 16),
        slot: PlanEventSlot.afterIsha,
        placeLabel: 'ديوان بيت الحمدي',
      ),
      PlanEvent(
        id: 'e-maqeel',
        type: PlanEventType.maqeel,
        date: DateTime(2027, 2, 17),
        slot: PlanEventSlot.afterAsr,
      ),
      PlanEvent(
        id: 'e-lunch',
        type: PlanEventType.lunch,
        date: DateTime(2027, 2, 18),
        slot: PlanEventSlot.dhuhr,
        placeLabel: 'بيت العريس',
      ),
    ],
    suggestions: const [],
  );

  @override
  Future<void> load(String weddingPlanId) async {}
}

class _Dashboard extends DashboardSummaryProvider {
  _Dashboard()
    : super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );

  final _summary = DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'عرس عبدالله الحمدي',
    'city': 'صنعاء',
    'weddingDate': '2027-02-18',
    'currency': 'YER',
    'status': 'PLANNING',
    'permissions': {'isOwner': true, 'role': 'OWNER'},
  });

  @override
  DashboardSummary? get summary => _summary;

  @override
  Future<void> loadDashboard(String weddingPlanId, {sharedMember}) async {}
}

/// A stand-in for the hosts' photo: a night sky over a hall, drawn here so
/// the golden shows how a real picture sits in both previews.
Future<void> _seedPhoto(WidgetTester tester) async {
  final image = await tester.runAsync(() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(800, 600);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          AarastV3Color.primaryDark,
          AarastV3Color.primary,
        ]),
    );
    canvas.drawCircle(
      const Offset(620, 140),
      70,
      Paint()..color = AarastV3Color.saffron,
    );
    final hall = Paint()..color = AarastV3Color.brandAccentSoft;
    canvas.drawRect(const Rect.fromLTWH(120, 330, 560, 270), hall);
    canvas.drawRect(
      const Rect.fromLTWH(360, 430, 80, 170),
      Paint()..color = AarastV3Color.brandAccentStrong,
    );
    return recorder.endRecording().toImage(800, 600);
  });
  // RA-MO-364: the saved photo is read through the app's own provider,
  // decoded at the card's capture width; the drawn picture is put under it.
  final key = await invitationPhoto(_photo).obtainKey(ImageConfiguration.empty);
  imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image!)),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double height = 3000,
  bool send = false,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await _seedPhoto(tester);
  final api = _Api();
  final provider = GuestsProvider(api);
  await provider.loadGuests('plan-1');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        ChangeNotifierProvider<PlanEventsProvider>.value(value: _Events()),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(
          value: _Dashboard(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: appTextScaler(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: JourneyProfileScope(
              profile: JourneyProfile.groom,
              child: child!,
            ),
          ),
        ),
        home: send
            ? const GuestSendScreen(
                weddingPlanId: 'plan-1',
                initialAudience: 'remind',
              )
            : const GuestInviteScreen(weddingPlanId: 'plan-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(
  WidgetTester tester,
  String name, {
  Type screen = GuestInviteScreen,
}) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(screen),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('invite at 360', (tester) async {
    await _pump(tester, width: 360);
    await _expectGolden(tester, 'guest_invite_360');
  });

  testWidgets('invite at 320', (tester) async {
    await _pump(tester, width: 320);
    await _expectGolden(tester, 'guest_invite_320');
  });

  testWidgets('invite at 360, text scale 1.3', (tester) async {
    await _pump(tester, width: 360, height: 3800, textScale: 1.3);
    await _expectGolden(tester, 'guest_invite_360_scale13');
  });

  testWidgets('the page the link opens, at 360', (tester) async {
    await _pump(tester, width: 360);
    await tester.tap(find.text('صفحة الدعوة'));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'guest_invite_page_360');
  });

  // Changed on purpose (D116): the invite screen's reminder mode (guest_reminder_*) → the send screen's «ما ردّوا» audience (guest_send_remind_*).
  testWidgets('reminder at 360', (tester) async {
    await _pump(tester, width: 360, height: 1400, send: true);
    expect(find.byKey(const ValueKey('send-unreachable')), findsOneWidget);
    await _expectGolden(
      tester,
      'guest_send_remind_360',
      screen: GuestSendScreen,
    );
  });

  testWidgets('reminder at 320', (tester) async {
    await _pump(tester, width: 320, height: 1400, send: true);
    await _expectGolden(
      tester,
      'guest_send_remind_320',
      screen: GuestSendScreen,
    );
  });

  testWidgets('a field typed into at 320 with the keyboard open', (
    tester,
  ) async {
    await _pump(tester, width: 320, height: 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    // Changed on purpose (D116): the card's map link field → its free text (the map link is each occasion's).
    await tester.ensureVisible(find.byKey(const ValueKey('invite-free-text')));
    await tester.showKeyboard(
      find.descendant(
        of: find.byKey(const ValueKey('invite-free-text')),
        matching: find.byType(EditableText),
      ),
    );
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'guest_invite_keyboard_320');
  });
}
