// Visual preview for the NEW premium guest widgets
// (phase/mobile-premium-screens-v1): GuestMeterHero + SmartGuestCard.
//
// Regenerate with:
//   flutter test test/premium_guests_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/premium/guest_meter_hero.dart';
import 'package:aarast_mobile/features/guests/widgets/premium/smart_guest_card.dart';

import 'support/preview_fonts.dart';

final _now = DateTime(2026, 7, 4);

Guest _guest({
  required String name,
  required String status,
  String? phone,
  String side = 'GROOM',
  int seats = 1,
  int companions = 0,
  String? notes,
}) {
  return Guest(
    id: name,
    weddingPlanId: 'p1',
    name: name,
    phone: phone,
    side: side,
    status: status,
    attendanceStatus: status == 'CONFIRMED'
        ? 'CONFIRMED'
        : status == 'DECLINED'
            ? 'DECLINED'
            : 'PENDING',
    seatsCount: seats,
    companionsCount: companions,
    invitationStatus: 'INVITED',
    notes: notes,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pump(WidgetTester tester, Widget child,
    {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('guests — active list (420)', (tester) async {
    final guests = [
      _guest(
        name: 'محمد علي',
        status: 'CONFIRMED',
        phone: '+967777123456',
        side: 'GROOM',
        seats: 2,
        companions: 1,
      ),
      _guest(
        name: 'ليلى سالم',
        status: 'PENDING',
        phone: '+967777654321',
        side: 'BRIDE',
      ),
      _guest(name: 'ضيف بدون رقم', status: 'INVITED', side: 'GROOM'),
    ];
    final summary = GuestSummary.fromGuests(
      weddingPlanId: 'p1',
      guests: guests,
      groups: const [],
    );
    await _pump(
      tester,
      Column(
        children: [
          GuestMeterHero(summary: summary),
          const SizedBox(height: 14),
          for (final g in guests) ...[
            SmartGuestCard(
              guest: g,
              groupLabel: 'العائلة',
              isDuplicate: false,
              isBusy: false,
              onEdit: () {},
              onStatus: (_) {},
              onDelete: () {},
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
      size: const Size(420, 1300),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_guests_active.png'),
    );
  });

  testWidgets('guests — fresh empty hero (420)', (tester) async {
    final summary = GuestSummary.fromGuests(
      weddingPlanId: 'p1',
      guests: const [],
      groups: const [],
    );
    await _pump(
      tester,
      GuestMeterHero(summary: summary, isLocalPlan: true),
      size: const Size(420, 300),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_guests_fresh.png'),
    );
  });
}
