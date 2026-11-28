import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_settings_screen.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/notification_settings_harness.dart';
import '../provider_portal/provider_profile_test.dart' show ProfileApi;

// REFINEMENT_SPEC 2.5, «إعدادات الإشعارات»: «هذا الجوال» first, apart from
// the account's switches; each switch says what it covers (the server's
// coverage, as this reader gets it) and when it comes, or that nothing of
// it comes; the night line only where phone notifications work. The phone,
// the roles and the server are faked at their edges
// (test/support/notification_settings_harness.dart).

const _switchKeys = [
  Key('settings-task-reminders-switch'),
  Key('settings-payment-reminders-switch'),
  Key('settings-booking-reminders-switch'),
  Key('settings-provider-messages-switch'),
];

Future<NotificationSettingsWorld> _pump(
  WidgetTester tester, {
  PushPhoneState? phone = PushPhoneState.on,
  Set<String> blocked = const {},
  FakeNotificationSettingsApi? api,
  bool owner = true,
  bool member = false,
  bool provider = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final world = await NotificationSettingsWorld.create(
    phone: phone,
    blocked: blocked,
    api: api,
    owner: owner,
    member: member,
    provider: provider,
  );
  // A new key each time: a test that pumps several worlds gets a new page
  // for each, as opening the page does, not the last one's state.
  await tester.pumpWidget(
    MultiProvider(
      key: UniqueKey(),
      providers: world.providers,
      child: MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

/// Lets a toast leave the screen before the test ends.
Future<void> _toastGone(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

JourneyToggle _toggle(WidgetTester tester, Key row) => tester.widget(
  find.descendant(of: find.byKey(row), matching: find.byType(JourneyToggle)),
);

void main() {
  group('هذا الجوال', () {
    final cases = <(PushPhoneState?, Set<String>, String, Key?)>[
      (PushPhoneState.on, {}, 'إشعارات الجوال تعمل', null),
      (
        PushPhoneState.notAsked,
        {},
        'إشعارات الجوال غير مفعّلة',
        const Key('settings-phone-allow'),
      ),
      (
        PushPhoneState.off,
        {},
        'إشعارات الجوال متوقفة من إعدادات الجوال',
        const Key('settings-phone-open-settings'),
      ),
      (
        PushPhoneState.channelsOff,
        {'aarast_money'},
        'إشعارات المال متوقفة في الجوال',
        const Key('settings-phone-open-channel'),
      ),
      (
        PushPhoneState.notLinked,
        {},
        'لم يكتمل ربط هذا الجوال، وسنعيد المحاولة',
        null,
      ),
      (null, {}, 'هذا الجوال لا يستقبل إشعارات خارج التطبيق', null),
    ];
    for (final (state, blocked, line, action) in cases) {
      testWidgets('${state?.name ?? 'no push'}: «$line», '
          '${action == null ? 'no button' : 'one button'}', (tester) async {
        await _pump(tester, phone: state, blocked: blocked);
        expect(find.text(line), findsOneWidget);
        for (final key in const [
          Key('settings-phone-allow'),
          Key('settings-phone-open-settings'),
          Key('settings-phone-open-channel'),
        ]) {
          expect(
            find.byKey(key),
            key == action ? findsOneWidget : findsNothing,
          );
        }
        // No warning colour and no coloured edge on the row.
        final row = tester.widget<JourneyBox>(
          find.byKey(Key('settings-phone-${state?.name ?? 'unavailable'}')),
        );
        expect(row.borderColor, isNull);
        expect(row.color, AarastV3Color.paper);
      });
    }

    testWidgets('unknown keeps the row\'s room and says nothing', (
      tester,
    ) async {
      await _pump(tester, phone: PushPhoneState.unknown);
      final row = find.byKey(const Key('settings-phone-unknown'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(AarastV3Size.row),
      );
    });

    testWidgets('shows while the settings have not loaded', (tester) async {
      await _pump(
        tester,
        phone: PushPhoneState.off,
        api: FakeNotificationSettingsApi(server: SettingsServer.neverAnswers),
      );
      expect(
        find.text('إشعارات الجوال متوقفة من إعدادات الجوال'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-switches-loading')),
        findsOneWidget,
      );
    });

    testWidgets('«اسمح» asks the phone once, then says it works', (
      tester,
    ) async {
      final world = await _pump(tester, phone: PushPhoneState.notAsked);
      world.push!.stateAfterAsk = PushPhoneState.on;
      await tester.tap(find.byKey(const Key('settings-phone-allow')));
      await tester.pump();
      expect(world.push!.asks, 1);
      // The row says it in place; a toast would say it twice.
      expect(find.text('إشعارات الجوال تعمل'), findsOneWidget);
      expect(find.text('فُعّلت إشعارات الجوال.'), findsNothing);
    });

    testWidgets('turned off: opens the phone\'s settings, reads again on the '
        'way back, and says it when they came back on', (tester) async {
      final world = await _pump(tester, phone: PushPhoneState.off);
      await tester.tap(find.byKey(const Key('settings-phone-open-settings')));
      await tester.pump();
      expect(world.push!.settingsOpened, 1);

      // Allowed in the phone: this phone is linked, then the state read.
      world.push!.state = PushPhoneState.notLinked;
      final readsBefore = world.push!.reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      world.push!.state = PushPhoneState.on;
      await tester.pump();
      await tester.pump();
      expect(world.push!.reads, greaterThan(readsBefore));
      expect(world.push!.linked, 1);
      expect(find.text('إشعارات الجوال تعمل'), findsOneWidget);
      expect(find.text('فُعّلت إشعارات الجوال.'), findsOneWidget);
      await _toastGone(tester);
    });

    testWidgets('a phone that will not open its settings gets the path by '
        'hand', (tester) async {
      final world = await _pump(tester, phone: PushPhoneState.off);
      world.push!.settingsOpen = false;
      await tester.tap(find.byKey(const Key('settings-phone-open-settings')));
      await tester.pump();
      expect(
        find.text(
          'لم تُفتح الإعدادات. افتحها بنفسك: الإعدادات، ثم التطبيقات، ثم '
          'اعّرست، ثم الإشعارات.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('two channels off are named, and the first one opens', (
      tester,
    ) async {
      final world = await _pump(
        tester,
        phone: PushPhoneState.channelsOff,
        blocked: {'aarast_money', 'aarast_messages'},
      );
      expect(
        find.text('إشعارات الرسائل والمال متوقفة في الجوال'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-phone-open-channel')));
      await tester.pump();
      expect(world.push!.channelsOpened, ['aarast_messages']);
    });

    testWidgets('the phone\'s permission never changes a switch', (
      tester,
    ) async {
      for (final state in [
        PushPhoneState.on,
        PushPhoneState.off,
        PushPhoneState.notAsked,
        PushPhoneState.channelsOff,
        PushPhoneState.notLinked,
        PushPhoneState.unknown,
        null,
      ]) {
        final world = await _pump(
          tester,
          phone: state,
          blocked: const {'aarast_tasks'},
          api: FakeNotificationSettingsApi(bookings: false),
        );
        expect(
          [for (final key in _switchKeys) _toggle(tester, key).value],
          [true, true, false, true],
          reason: '$state',
        );
        expect(world.api.saved, isEmpty, reason: '$state');
      }
    });

    testWidgets('the night line shows only while phone notifications work', (
      tester,
    ) async {
      for (final (state, shows) in [
        (PushPhoneState.on, true),
        (PushPhoneState.channelsOff, true),
        (PushPhoneState.off, false),
        (PushPhoneState.notAsked, false),
        (PushPhoneState.notLinked, false),
        (PushPhoneState.unknown, false),
        (null, false),
      ]) {
        await _pump(tester, phone: state, blocked: const {'aarast_money'});
        expect(
          find.byKey(const Key('settings-night-line')),
          shows ? findsOneWidget : findsNothing,
          reason: '$state',
        );
      }
      await _pump(tester);
      expect(
        find.text(
          'بين 9 مساءً و9 صباحًا نؤجّل إشعارات الجوال إلى 9 صباحًا، إلا '
          'الرسائل وطلبات الحجز. وفي آخر أسبوع قبل العرس ويوم العرس يصلك ما '
          'يغيّر عرسك في أي وقت.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('شاشة القفل'), findsNothing);
      expect(find.textContaining('فور وصولها'), findsNothing);
    });
  });

  group('ما يصلك منّا', () {
    testWidgets('four switches, each with what it covers and when, for the '
        'owner', (tester) async {
      await _pump(tester);
      expect(find.text('داخل التطبيق وعلى الجوال'), findsOneWidget);
      for (final title in [
        'المهام',
        'المال',
        'تذكير بموعد الحجز',
        'المزوّدون والحجوزات',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        find.text('يشمل إسناد مهمة إليك، وتذكيرات المهام، والعدّ إلى العرس.'),
        findsOneWidget,
      );
      expect(find.textContaining('وسداد السُّلف'), findsOneWidget);
      expect(find.textContaining('والمال الموعود قبل موعده'), findsOneWidget);
      expect(find.text('قبل موعدها بأسبوع وبيوم'), findsOneWidget);
      expect(
        find.text('تصلك دائمًا: الدعوات وملخص ردود الضيوف.'),
        findsOneWidget,
      );
      // Each switch is named to a screen reader by its title.
      for (final key in _switchKeys) {
        expect(_toggle(tester, key).semanticLabel, isNotEmpty);
      }
      // The row reads as one element: its words and its switch's state.
      final handle = tester.ensureSemantics();
      await tester.pump();
      final node = find.semantics
          .byLabel(RegExp('^المهام\\s+يشمل إسناد مهمة إليك'))
          .evaluate()
          .single;
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('a participant: payments only, and what a member always gets', (
      tester,
    ) async {
      await _pump(tester, owner: false, member: true);
      expect(find.text('يشمل مواعيد الدفعات.'), findsOneWidget);
      expect(find.textContaining('السُّلف'), findsNothing);
      expect(find.textContaining('المال الموعود'), findsNothing);
      expect(find.textContaining('تغيّر صلاحياتك في الخطة'), findsOneWidget);
    });

    testWidgets('an account with a provider profile hears of its customers', (
      tester,
    ) async {
      await _pump(tester, provider: true);
      expect(find.textContaining('وطلبات عملائك ورسائلهم.'), findsOneWidget);
    });

    testWidgets('a switch turned off says nothing of it comes, and no timing', (
      tester,
    ) async {
      await _pump(tester, api: FakeNotificationSettingsApi(bookings: false));
      final row = find.byKey(_switchKeys[2]);
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            'لا يصلك شيء من هذا، لا داخل التطبيق ولا على الجوال.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text('قبل موعدها بأسبوع وبيوم'),
        ),
        findsNothing,
      );
    });

    testWidgets('every switch rests while one is saved', (tester) async {
      final api = FakeNotificationSettingsApi()..saveGate = Completer<void>();
      await _pump(tester, api: api);
      await tester.tap(find.byKey(_switchKeys.first));
      await tester.pump();
      for (final key in _switchKeys) {
        expect(_toggle(tester, key).onChanged, isNull, reason: '$key');
      }
      api.saveGate!.complete();
      await tester.pumpAndSettle();
      for (final key in _switchKeys) {
        expect(_toggle(tester, key).onChanged, isNotNull, reason: '$key');
      }
      expect(api.saved.single['taskRemindersEnabled'], isFalse);
    });

    testWidgets('a refused save puts the switch back and says so', (
      tester,
    ) async {
      final api = FakeNotificationSettingsApi()..saveFails = true;
      await _pump(tester, api: api);
      await tester.tap(find.byKey(_switchKeys[1]));
      await tester.pump();
      await tester.pump();
      expect(_toggle(tester, _switchKeys[1]).value, isTrue);
      expect(
        find.text('لم يُحفظ التغيير، فأعدنا المفتاح كما كان. أعد المحاولة.'),
        findsOneWidget,
      );
      await _toastGone(tester);
    });

    testWidgets('the phone\'s copy, offline: one line, the switches work', (
      tester,
    ) async {
      await _pump(
        tester,
        api: FakeNotificationSettingsApi(
          server: SettingsServer.offlineWithCopy,
        ),
      );
      expect(
        find.text('آخر نسخة محفوظة، وتغييراتك تُرسل عند الاتصال'),
        findsOneWidget,
      );
      expect(find.text('إشعارات الجوال تعمل'), findsOneWidget);
      expect(_toggle(tester, _switchKeys.first).onChanged, isNotNull);
    });

    testWidgets('not loaded yet: fixed rows in the switches\' place', (
      tester,
    ) async {
      await _pump(
        tester,
        api: FakeNotificationSettingsApi(server: SettingsServer.neverAnswers),
      );
      final loading = find.byKey(const Key('settings-switches-loading'));
      expect(loading, findsOneWidget);
      expect(find.byType(JourneyToggle), findsNothing);
      expect(find.byKey(const Key('settings-always-line')), findsNothing);
      // The same room the four rows take, so nothing jumps when they come.
      expect(tester.getSize(loading).height, greaterThan(4 * AarastV3Size.row));
    });

    testWidgets('failed with no copy: one line and a retry', (tester) async {
      final api = FakeNotificationSettingsApi(server: SettingsServer.fails);
      await _pump(tester, api: api);
      expect(find.text('لم نتمكن من تحميل اختياراتك.'), findsOneWidget);
      final calls = api.getCalls;
      await tester.tap(find.text('أعد المحاولة'));
      await tester.pumpAndSettle();
      expect(api.getCalls, calls + 1);
    });
  });

  testWidgets('the provider\'s page: the same phone row, his one switch, '
      'his words', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final world = await NotificationSettingsWorld.create(
      owner: false,
      provider: true,
    );
    final dashboard = ProviderDashboardProvider(ProfileApi());
    await dashboard.loadDashboard();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...world.providers,
          ChangeNotifierProvider<ProviderDashboardProvider>.value(
            value: dashboard,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProviderSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إشعارات الجوال تعمل'), findsOneWidget);
    expect(find.byType(JourneyToggle), findsOneWidget);
    expect(find.text('طلبات العملاء ورسائلهم'), findsOneWidget);
    expect(find.textContaining('يشمل طلبات العرض والحجز'), findsOneWidget);
    expect(
      find.text(
        'تصلك دائمًا: قرارات الفريق على ملفك وصورك وتغيّر ظهورك المميّز.',
      ),
      findsOneWidget,
    );
    final night = tester.widget<Text>(
      find.byKey(const Key('settings-night-line')),
    );
    expect(night.data, isNot(contains('العرس')));
    expect(find.textContaining('تنبيه'), findsNothing);
    await tester.tap(find.byKey(const Key('provider-settings-messages')));
    await tester.pumpAndSettle();
    expect(world.api.saved.single['providerMessagesEnabled'], isFalse);
  });
}
