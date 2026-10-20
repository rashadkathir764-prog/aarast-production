// Throwaway design prototype: the provider journey, in a neutral slate.
//   flutter test test/prototype/provider/provider_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../c_journey/kit.dart';
import '../../support/preview_fonts.dart';
import 'p_join.dart';
import 'p_more.dart';
import 'p_requests.dart';

Future<void> _shot(WidgetTester tester, String name, Widget screen, double h) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fTaj),
      home: Material(child: screen),
    ),
  );
  await tester.pump();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  final screens = <(String, Widget Function(), double)>[
    ('p01_register', p01Register, 844), ('p02_claim', p02Claim, 900),
    ('p03_business', p03Business, 960), ('p04_where', p04Where, 900), ('p05_work', p05Work, 960),
    ('p05b_model', p05bModel, 900), ('p06_units', p06Units, 1100), ('p06c_catalog', p06Catalog, 960),
    ('p07_submit', p07Submit, 1000), ('p08_pending', p08Pending, 900), ('p09_needs_changes', p09NeedsChanges, 1000),
    ('p10_approved', p10Approved, 900), ('p11_rejected', p11Rejected, 844), ('p12_suspended', p12Suspended, 900),
    ('p13_home', p13Home, 1000), ('p14_home_new', p14HomeNew, 960),
    ('p15_requests', p15Requests, 1000), ('p16_request', p16Request, 1000), ('p16c_order', p16Order, 960),
    ('p17_offer', p17Offer, 1080), ('p18_decline', p18Decline, 900), ('p19_offer_sent', p19OfferSent, 900),
    ('p20_ended', p20Ended, 1000), ('p21_confirm', p21Confirm, 960), ('p22_booking', p22Booking, 1040),
    ('p23_deposit', p23Deposit, 900), ('p24_changed', p24Changed, 900), ('p25_cancelled', p25Cancelled, 1000),
    ('p26_after', p26After, 1000), ('p26c_order_done', p26Order, 844), ('p27_review', p27Review, 960),
    ('p28_month', p28Month, 1000), ('p29_day', p29Day, 960), ('p30_outside', p30Outside, 960),
    ('p31_hold', p31Hold, 900), ('p32_fresh', p32Fresh, 960),
    ('p33_chats', p33Chats, 844), ('p34_chat', p34Chat, 900),
    ('p35_me', p35Me, 1000), ('p36_services', p36Services, 1040), ('p37_gallery', p37Gallery, 1000),
    ('p38_verify', p38Verify, 960), ('p39_performance', p39Performance, 960), ('p40_settings', p40Settings, 960),
    ('p41_claim_link', p41ClaimLink, 900), ('p42_notifications', p42Notifications, 900), ('p43_offline', p43Offline, 900),
  ];

  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2(), s.$3));
  }
}
