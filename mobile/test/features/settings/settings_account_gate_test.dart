import 'dart:convert';
import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/settings/models/preference_coverage.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/utils/auth_action_guard.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings account gate prevents protected API calls', (
    tester,
  ) async {
    final fakeApi = _FakeSettingsApi();
    await _pumpSettings(tester, fakeApi);

    expect(find.byKey(const Key('sharing-auth-gate')), findsOneWidget);
    expect(find.text('سجّل الدخول لإدارة الإعدادات'), findsOneWidget);
    expect(find.text(AuthActionGuard.sharingLoginGateTitle), findsNothing);
    expect(find.text('حفظ الإعدادات'), findsNothing);
    expect(fakeApi.getSettingsCalls, 0);
    expect(fakeApi.updateSettingsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings account gate remains stable at 320px RTL width', (
    tester,
  ) async {
    final fakeApi = _FakeSettingsApi();
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSettings(tester, fakeApi);

    expect(find.text('سجّل الدخول لإدارة الإعدادات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signed-in settings expose only real notification preferences at 320px RTL',
    (tester) async {
      final fakeApi = _FakeSettingsApi();
      await tester.binding.setSurfaceSize(const Size(320, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpSignedInSettings(tester, fakeApi);

      expect(find.byType(JourneyToggle), findsNWidgets(4));
      expect(
        find.byKey(const Key('settings-task-reminders-switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-payment-reminders-switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-booking-reminders-switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-provider-messages-switch')),
        findsOneWidget,
      );
      expect(find.text('التنبيهات المهمة'), findsNothing);
      expect(find.text('واتساب'), findsNothing);
      expect(find.text('رسائل SMS'), findsNothing);
      expect(find.text('البريد الإلكتروني'), findsNothing);
      // g07 (D24): the server's reminders, each with when it comes from the
      // server's own table. Changed on purpose (REFINEMENT_SPEC 2.5): the
      // titles say what each switch governs («المال»، «تذكير بموعد الحجز»،
      // «المزوّدون والحجوزات»), the offers' «فور وصولها» went (they wait for
      // the morning at night), and the lock-screen note went. The phone's
      // rows and the coverage lines are notification_settings_test.dart's.
      expect(find.text('المهام'), findsOneWidget);
      expect(
        find.text(
          'قبل موعدها بأسبوع وبيوم، وفي يومها، ومرة إن تأخرت، '
          'وفي الوقت الذي تختاره لها، وإن كان ليلًا وصل جوالك صباحًا',
        ),
        findsOneWidget,
      );
      expect(find.text('المال'), findsOneWidget);
      expect(
        find.textContaining('قبل موعدها بأسبوع أو في يوم التذكير'),
        findsOneWidget,
      );
      // RA-BE-190: the booking reminders are their own switch.
      expect(find.text('تذكير بموعد الحجز'), findsOneWidget);
      expect(find.text('قبل موعدها بأسبوع وبيوم'), findsOneWidget);
      expect(find.text('المزوّدون والحجوزات'), findsOneWidget);
      expect(find.textContaining('فور وصولها'), findsNothing);
      expect(find.textContaining('شاشة القفل'), findsNothing);
      expect(find.text('ملخص الجمعة'), findsNothing);

      for (final key in const [
        Key('settings-task-reminders-switch'),
        Key('settings-payment-reminders-switch'),
        Key('settings-booking-reminders-switch'),
        Key('settings-provider-messages-switch'),
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(JourneyToggle),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Each switch saves the moment it is switched; no save button.
      expect(find.text('حفظ الإعدادات'), findsNothing);
      expect(fakeApi.updateSettingsCalls, 4);
      expect(fakeApi.lastUpdatePayload, {
        'taskRemindersEnabled': false,
        'paymentRemindersEnabled': false,
        'providerMessagesEnabled': false,
        'bookingRemindersEnabled': false,
      });
      expect(fakeApi.lastUpdatePayload, isNot(contains('pushEnabled')));
      expect(fakeApi.lastUpdatePayload, isNot(contains('smsEnabled')));
      expect(fakeApi.lastUpdatePayload, isNot(contains('whatsappEnabled')));
      expect(fakeApi.lastUpdatePayload, isNot(contains('emailEnabled')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings do not claim push when this app build lacks Firebase', (
    tester,
  ) async {
    final fakeApi = _FakeSettingsApi();
    // No push on this build: the shared «هذا الجوال» row says so (MSA,
    // REFINEMENT_SPEC 2.5), and the night line, the phone's, never shows.
    await _pumpSignedInSettings(tester, fakeApi);

    expect(
      find.text('هذا الجوال لا يستقبل إشعارات خارج التطبيق'),
      findsOneWidget,
    );
    expect(find.textContaining('شاشة القفل'), findsNothing);
    expect(find.byKey(const Key('settings-night-line')), findsNothing);
  });

  testWidgets('without the server\'s table the switches say no timing', (
    tester,
  ) async {
    final fakeApi = _FakeSettingsApi(withSchedule: false);
    await _pumpSignedInSettings(tester, fakeApi);

    expect(find.text('المهام'), findsOneWidget);
    expect(find.textContaining('قبل موعدها'), findsNothing);
    expect(find.textContaining('يشمل'), findsNothing);
    expect(find.byKey(const Key('settings-night-line')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _FakeSettingsApi fakeApi,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final authController = AuthController(authRepository)..restoreSession();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(fakeApi),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSignedInSettings(
  WidgetTester tester,
  _FakeSettingsApi fakeApi,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'settings-test-token',
    user: _SignedInAuthRepository.user,
  );
  final authRepository = _SignedInAuthRepository(authStorage);
  final authController = AuthController(authRepository);
  await authController.restoreSession();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(fakeApi),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSettingsApi extends SettingsApi {
  _FakeSettingsApi({this.withSchedule = true})
    : super(ApiClient(tokenProvider: () async => null));

  final bool withSchedule;

  /// The server's own answer, kept by the backend's reminder-schedule test.
  @override
  Future<NotificationSchedule> getNotificationSchedule() async {
    if (!withSchedule) throw StateError('no network');
    return NotificationSchedule.fromResponse(
      jsonDecode(
        File('test/fixtures/reminder_schedule.json').readAsStringSync(),
      ),
    );
  }

  @override
  Future<NotificationSchedule?> cachedNotificationSchedule() async => null;

  int getSettingsCalls = 0;
  int updateSettingsCalls = 0;
  Map<String, dynamic>? lastUpdatePayload;

  @override
  Future<UserSettings> getSettings() async {
    getSettingsCalls += 1;
    return UserSettings(
      id: 'settings-1',
      userId: 'user-1',
      pushEnabled: false,
      whatsappEnabled: false,
      emailEnabled: false,
      smsEnabled: false,
      taskRemindersEnabled: true,
      paymentRemindersEnabled: true,
      providerMessagesEnabled: true,
      bookingRemindersEnabled: true,
      channelCapabilities: const NotificationChannelCapabilities(
        inApp: NotificationChannelCapability(
          supported: true,
          configurable: false,
          enabled: true,
        ),
        push: NotificationChannelCapability(
          supported: true,
          configurable: false,
          enabled: false,
        ),
        sms: NotificationChannelCapability(
          supported: false,
          configurable: false,
          enabled: false,
        ),
        whatsapp: NotificationChannelCapability(
          supported: false,
          configurable: false,
          enabled: false,
        ),
        email: NotificationChannelCapability(
          supported: false,
          configurable: false,
          enabled: false,
        ),
      ),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    updateSettingsCalls += 1;
    lastUpdatePayload = settings.toUpdateJson();
    return settings;
  }
}

class _SignedInAuthRepository extends AuthRepository {
  _SignedInAuthRepository(AuthStorage storage)
    : super(
        ApiClient(tokenProvider: () async => 'settings-test-token'),
        storage,
      );

  static const user = SafeUser(
    id: 'user-1',
    name: 'مستخدم الإعدادات',
    phone: '+967777000000',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  Future<String?> readAccessToken() async => 'settings-test-token';

  @override
  SafeUser? readCachedUser() => user;

  @override
  Future<SafeUser> me() async => user;
}
