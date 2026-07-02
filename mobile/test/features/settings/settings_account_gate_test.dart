import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
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

class _FakeSettingsApi extends SettingsApi {
  _FakeSettingsApi() : super(ApiClient(tokenProvider: () async => null));

  int getSettingsCalls = 0;
  int updateSettingsCalls = 0;

  @override
  Future<UserSettings> getSettings() async {
    getSettingsCalls += 1;
    return UserSettings(
      id: 'settings-1',
      userId: 'user-1',
      pushEnabled: true,
      whatsappEnabled: false,
      emailEnabled: false,
      smsEnabled: false,
      taskRemindersEnabled: true,
      paymentRemindersEnabled: true,
      providerMessagesEnabled: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    updateSettingsCalls += 1;
    return settings;
  }
}
