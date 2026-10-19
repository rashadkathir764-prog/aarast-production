// Throwaway design prototype v3: the groom's full journey with the men's and
// women's weddings, the missing screens and the UX additions.
//   flutter test test/prototype/v3/v3_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../c_journey/kit.dart';
import '../c_journey/screens_start.dart' show otp;
import '../../support/preview_fonts.dart';
import 'hard.dart';
import 'home.dart';
import 'lights.dart';
import 'money.dart';
import 'more.dart';
import 'sections.dart';
import 'start.dart';
import 'touches.dart';

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen,
  double h,
) async {
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
  // Decode photos for real before the shot.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  final screens = <(String, Widget Function(), double)>[
    ('a01_splash', vSplash2, 844),
    ('a02_who', vWho2, 844),
    ('a03_name', vName, 844),
    ('a04_date', vDate, 844),
    ('a05_city', vCity, 844),
    ('a06_mahr', vMahr, 900),
    ('a07_budget', vBudget, 844),
    ('a08_ready', vReady, 844),
    ('a09_otp', otp, 844),
    ('b01_home_fresh', vHomeFresh, 960),
    ('b02_home_active', vHomeActive, 1400),
    ('b03_quick_entry', vQuickEntry, 844),
    ('b04_home_week', vHomeWeek, 1300),
    ('b05_home_day', vHomeDay, 1000),
    ('b06_rafd', vRafd, 900),
    ('b07_home_after', vHomeAfter, 1180),
    ('b08_notifications', vNotifications, 900),
    ('b09_widget', vWidget, 844),
    ('b10_dark', vDarkHome, 844),
    ('c01_money_summary', vMoneySummary, 1240),
    ('c02_money_items', vMoneyItems, 1500),
    ('c03_money_payments', vMoneyPayments, 960),
    ('c04_money_offline', () => vMoneyPayments(offline: true), 1000),
    ('c05_money_funding', vMoneyFunding, 960),
    ('c06_pay_sheet', vPaySheet, 900),
    ('c07_item_detail', vItemDetail, 1000),
    ('c08_what_if', vWhatIf, 900),
    ('d01_tasks', vTasks, 1100),
    ('d02_add_task', vAddTask, 900),
    ('e01_guests_men', vGuestsMen, 1100),
    ('e03_contacts', vContacts, 900),
    ('e04_invite', vInvite, 960),
    ('e05_rsvp', vRsvp, 900),
    ('f01_prov_requests', vProvRequests, 1000),
    ('f02_prov_explore', vProvExplore, 1080),
    ('f03_prov_page', vProvPage, 1000),
    ('f04_compare', vCompare, 844),
    ('f05_book_sheet', vBookSheet, 900),
    ('f06_chat', vChat, 844),
    ('g01_family', vFamily, 960),
    ('g02_account', vAccount, 1060),
    ('g03_postpone', vPostpone, 900),
    ('g04_rate', vRate, 980),
    ('g05_book', vBook, 900),
    ('a10_login', vLogin, 844), ('b11_assistant', vAssistant, 960), ('b12_events', vEvents, 900), ('b13_event_edit', vEventEdit, 900), ('b14_loading', vLoading, 844), ('b15_error', vError, 844),
    ('c09_add_item', vAddItem, 900), ('c10_add_cost', vAddCost, 1000), ('c11_payment_detail', vPaymentDetail, 1000), ('c12_add_source', vAddSource, 960), ('c13_loan', vLoan, 900), ('c14_share', vShareSummary, 900),
    ('d03_starter', vStarterTasks, 1040), ('d04_task_detail', vTaskDetail, 1040), ('d05_contract_papers', vContractPapers, 1000),
    ('e06_add_guest', vAddGuest, 900), ('e07_guest_detail', vGuestDetail, 960), ('e08_reminder', vReminderPreview, 900), ('e09_rafd_book', vRafdBook, 1000), ('e10_thanks', vThanks, 900),
    ('f07_quote', vQuoteRequest, 960), ('f08_chats', vConversations, 900), ('f09_favorites', vFavorites, 900),
    ('g06_add_participant', vAddParticipant, 960), ('g07_notif', vNotifSettings, 960), ('g08_lock', vLock, 844), ('g09_change_phone', vChangePhone, 844), ('g10_support', vSupport, 1000), ('g11_logout', vLogout, 844),
    ('x01_home_no_date', vHomeNoDate, 900), ('x02_date_approx', vDateApprox, 844), ('x03_money_no_budget', vMoneyNoBudget, 960),
    ('x04_from_family', vFromFamily, 900), ('x05_invite_landing', vInviteLanding, 960), ('x06_helper_home', vHelperHome, 960), ('x07_participant_states', vParticipantStates, 960),
    ('x08_pledge_check', vPledgeCheck, 900),
    ('x09_prov_hard', vProvHard, 1040), ('x10_reject_offer', vRejectOffer, 900), ('x11_cancel_booking', vCancelBooking, 1000), ('x12_rate_sent', vRateSent, 960),
    ('x13_rafd_later', vRafdLater, 960),
    ('x14_payment_reversed', vPaymentReversed, 844), ('x15_cancel_item', vCancelItem, 844), ('x16_task_menu', vTaskMenu, 844),
    ('x17_otp_wrong', vOtpWrong, 844), ('x18_session_expired', vSessionExpired, 844),
    ('x19_conflict', vConflict, 844), ('x20_activity', vActivity, 900),
    ('y01_where_are_you', vWhereAreYou, 960), ('y02_expat_home', vExpatHome, 1040), ('y03_remit', vRemit, 1000),
    ('y04_custody', vCustody, 960), ('y05_hand_cash', vHandCash, 960),
    ('y06_moment_week', vMomentWeek, 900), ('y07_moment_day', vMomentDay, 844), ('y08_moment_mahr', vMomentMahr, 844), ('y09_moment_booked', vMomentBooked, 844),
    ('y10_father_home', vFatherHome, 960), ('y11_search', vSearch, 900),
    ('y12_lights_home', vLightsHome, 960), ('y13_decor_providers', vDecorProviders, 900), ('y14_fireworks_task', vFireworksTask, 960),
  ];

  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2(), s.$3));
  }
}
