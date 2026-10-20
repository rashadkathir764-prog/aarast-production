// Captures today's real guest screens for the groom before/after review.
//   flutter test test/prototype/now_guests/now_guests_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/preview_fonts.dart';

const _plan = 'plan-mohammed-salma';

class _Api extends GuestsApi {
  _Api(this.guests, this.groups)
    : super(ApiClient(tokenProvider: () async => null));

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

const _groups = [
  GuestGroup(id: 'g1', weddingPlanId: _plan, name: 'آل الحمدي'),
  GuestGroup(id: 'g2', weddingPlanId: _plan, name: 'آل السقاف'),
  GuestGroup(id: 'g3', weddingPlanId: _plan, name: 'زملاء العمل'),
  GuestGroup(id: 'g4', weddingPlanId: _plan, name: 'الأصحاب'),
];

Guest _g(
  int i,
  String name, {
  String? phone,
  String group = 'g1',
  String side = 'GROOM',
  String status = 'INVITED',
  String invitation = 'NOT_SENT',
  int companions = 0,
}) {
  final attendance = switch (status) {
    'CONFIRMED' => 'CONFIRMED',
    'DECLINED' => 'DECLINED',
    _ => 'PENDING',
  };
  return Guest(
    id: 'guest-$i',
    weddingPlanId: _plan,
    groupId: group,
    name: name,
    phone: phone,
    side: side,
    status: status,
    invitationStatus: invitation,
    attendanceStatus: attendance,
    seatsCount: 1 + companions,
    companionsCount: companions,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );
}

final _guests = [
  _g(1, 'عبدالله الحمدي', phone: '+967733455001', status: 'CONFIRMED', invitation: 'SENT', companions: 1),
  _g(2, 'أحمد الحمدي', phone: '+967777210334', status: 'CONFIRMED', invitation: 'SENT'),
  _g(3, 'علي الحمدي', phone: '+967771908120', invitation: 'SENT'),
  _g(4, 'هاني الحمدي', phone: '+967770112889'),
  _g(5, 'سالم السقاف', phone: '+967735660210', group: 'g2', side: 'BRIDE', status: 'CONFIRMED', invitation: 'SENT', companions: 2),
  _g(6, 'مراد السقاف', group: 'g2', side: 'BRIDE'),
  _g(7, 'ياسر الأهدل', phone: '+967777881002', group: 'g3', side: 'FRIEND', status: 'DECLINED', invitation: 'SENT'),
  _g(8, 'فهد ناجي', phone: '+967733445566', group: 'g3', side: 'FRIEND', invitation: 'SENT'),
  _g(9, 'سامي السنيدار', phone: '+967771234567', group: 'g4', side: 'FRIEND', status: 'CONFIRMED', invitation: 'SENT'),
  _g(10, 'نبيل العمري', group: 'g4', side: 'FRIEND'),
];

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required List<Guest> guests,
  List<GuestGroup> groups = _groups,
  double h = 1400,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final api = _Api(guests, groups);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GuestListScreen(weddingPlanId: _plan),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('guests empty', (tester) async {
    await _shot(tester, 'guests_empty', guests: const [], groups: const [], h: 844);
  });

  testWidgets('guests list', (tester) async {
    await _shot(tester, 'guests_list', guests: _guests, h: 1900);
  });

  testWidgets('add guest sheet', (tester) async {
    await _shot(
      tester,
      'guest_add',
      guests: _guests,
      h: 1100,
      act: () async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('add guest sheet details', (tester) async {
    await _shot(
      tester,
      'guest_add_details',
      guests: _guests,
      h: 1500,
      act: () async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.text('تفاصيل إضافية'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('تفاصيل إضافية'));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('edit guest sheet', (tester) async {
    await _shot(
      tester,
      'guest_edit',
      guests: _guests,
      h: 1500,
      act: () async {
        await tester.tap(find.text('عبدالله الحمدي'));
        await tester.pump(const Duration(milliseconds: 500));
        final more = find.text('تفاصيل إضافية');
        if (more.evaluate().isNotEmpty) {
          await tester.ensureVisible(more.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(more.first);
          await tester.pump(const Duration(milliseconds: 500));
        }
      },
    );
  });

  testWidgets('guest row menu', (tester) async {
    await _shot(
      tester,
      'guest_menu',
      guests: _guests,
      h: 1100,
      act: () async {
        await tester.tap(find.byTooltip('إجراءات الضيف').at(2));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('guest groups sheet', (tester) async {
    await _shot(
      tester,
      'guest_groups',
      guests: _guests,
      h: 1100,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('guest-groups-manage')));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
