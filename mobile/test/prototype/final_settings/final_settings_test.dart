// REFINEMENT_SPEC 2.5, the final proposal of «إعدادات الإشعارات» for the
// owner's review: the real pages (the couple's SettingsScreen and the
// provider's ProviderSettingsScreen) on a real 360×800 phone, with the
// phone's answer, the account's roles and the server's settings faked at
// their edges only (test/support/notification_settings_harness.dart).
//   flutter test --no-pub test/prototype/final_settings/final_settings_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_settings_screen.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../features/provider_portal/provider_profile_test.dart'
    show ProfileApi;
import '../../support/notification_settings_harness.dart';
import '../../support/preview_fonts.dart';
import '../support/phone_frame.dart';

Future<void> _couple(
  WidgetTester tester,
  String name, {
  PushPhoneState? phone = PushPhoneState.on,
  Set<String> blocked = const {},
  FakeNotificationSettingsApi? api,
  JourneyProfile profile = JourneyProfile.groom,
  bool owner = true,
  bool member = false,
  bool provider = false,
  PhoneSize size = PhoneSize.standard,
  double textScale = 1,
  double fullHeight = 2000,
}) async {
  final world = await NotificationSettingsWorld.create(
    phone: phone,
    blocked: blocked,
    api: api,
    owner: owner,
    member: member,
    provider: provider,
  );
  await phoneShot(
    tester,
    name,
    JourneyProfileScope(profile: profile, child: const SettingsScreen()),
    providers: world.providers,
    size: size,
    textScale: textScale,
    fullHeight: fullHeight,
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  group('the phone\'s states, groom who owns his plan', () {
    testWidgets('f01 on', (tester) async {
      await _couple(tester, 'f01_phone_on');
    });
    testWidgets('f02 never asked', (tester) async {
      await _couple(
        tester,
        'f02_phone_not_asked',
        phone: PushPhoneState.notAsked,
      );
    });
    testWidgets('f03 turned off in the phone', (tester) async {
      await _couple(tester, 'f03_phone_off', phone: PushPhoneState.off);
    });
    testWidgets('f04 the money channel off', (tester) async {
      await _couple(
        tester,
        'f04_phone_channel_off',
        phone: PushPhoneState.channelsOff,
        blocked: const {'aarast_money'},
      );
    });
    testWidgets('f05 not linked yet', (tester) async {
      await _couple(
        tester,
        'f05_phone_not_linked',
        phone: PushPhoneState.notLinked,
      );
    });
    testWidgets('f06 no phone notifications on this phone', (tester) async {
      await _couple(tester, 'f06_phone_unavailable', phone: null);
    });
    testWidgets('f07 the phone has not answered yet', (tester) async {
      await _couple(tester, 'f07_phone_unknown', phone: PushPhoneState.unknown);
    });
  });

  group('the settings\' states', () {
    testWidgets('f08 the phone\'s copy, offline', (tester) async {
      await _couple(
        tester,
        'f08_offline_copy',
        api: FakeNotificationSettingsApi(
          server: SettingsServer.offlineWithCopy,
        ),
      );
    });
    testWidgets('f09 not loaded yet', (tester) async {
      await _couple(
        tester,
        'f09_not_loaded',
        api: FakeNotificationSettingsApi(server: SettingsServer.neverAnswers),
      );
    });
    testWidgets('f10 a switch turned off', (tester) async {
      await _couple(
        tester,
        'f10_switch_off',
        api: FakeNotificationSettingsApi(tasks: false),
      );
    });
    testWidgets('f11 load failed, no copy', (tester) async {
      await _couple(
        tester,
        'f11_load_failed',
        api: FakeNotificationSettingsApi(server: SettingsServer.fails),
      );
    });
  });

  group('the readers', () {
    testWidgets('f12 bride who owns her plan', (tester) async {
      await _couple(tester, 'f12_bride', profile: JourneyProfile.bride);
    });
    testWidgets('f13 a participant with no plan of their own', (tester) async {
      await _couple(tester, 'f13_participant', owner: false, member: true);
    });
    testWidgets('f14 a groom who is also a provider', (tester) async {
      await _couple(tester, 'f14_groom_and_provider', provider: true);
    });
    testWidgets('f15 the provider\'s page', (tester) async {
      final world = await NotificationSettingsWorld.create(
        owner: false,
        provider: true,
      );
      final dashboard = ProviderDashboardProvider(ProfileApi());
      await dashboard.loadDashboard();
      await phoneShot(
        tester,
        'f15_provider_page',
        const ProviderSettingsScreen(),
        providers: [
          ...world.providers,
          ChangeNotifierProvider<ProviderDashboardProvider>.value(
            value: dashboard,
          ),
        ],
      );
    });
  });

  group('sizes', () {
    testWidgets('f16 320 at text 1.3, the phone turned off', (tester) async {
      await _couple(
        tester,
        'f16_320_text13_off',
        phone: PushPhoneState.off,
        size: PhoneSize.narrow,
        textScale: 1.3,
        fullHeight: 2600,
      );
    });
    testWidgets('f17 412 at text 1.0, bride', (tester) async {
      await _couple(
        tester,
        'f17_412_text10_bride',
        profile: JourneyProfile.bride,
        size: PhoneSize.large,
      );
    });
    testWidgets('f18 360 at text 0.85', (tester) async {
      await _couple(tester, 'f18_360_text085', textScale: 0.85);
    });
    testWidgets('f19 360 at text 2.0, a channel off', (tester) async {
      await _couple(
        tester,
        'f19_360_text20_channel_off',
        phone: PushPhoneState.channelsOff,
        blocked: const {'aarast_messages', 'aarast_money'},
        textScale: 2,
        fullHeight: 3600,
      );
    });
  });
}
