import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:aarast_mobile/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// g07: what happens after a task is given to someone is this phone's
// choice, kept on the phone; it shows with or without an account (a guest's
// plan gives tasks too) and never reaches the server.

void main() {
  testWidgets('the task message choice is kept on the phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final stored = await SharedPreferences.getInstance();
    final preferences = DevicePreferences(stored);
    final api = _NoSettingsApi();
    final storage = AuthStorage(stored);
    final repository = AuthRepository(
      ApiClient(tokenProvider: storage.readAccessToken),
      storage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: storage),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(repository),
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(api),
          ),
          ChangeNotifierProvider<DevicePreferences>.value(value: preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-task-message')), findsOneWidget);
    expect(find.text('لما تعطي مهمة لأحد'), findsOneWidget);
    expect(
      find.text('نجهّز له رسالة فيها المهمة وموعدها، تنرسل من جوالك أنت.'),
      findsOneWidget,
    );
    final ask = find.byKey(const Key('settings-task-message-ask'));
    expect(tester.widget<JourneyChip>(ask).selected, isTrue);

    for (final (key, mode) in const [
      ('settings-task-message-whatsApp', TaskMessageMode.whatsApp),
      ('settings-task-message-off', TaskMessageMode.off),
      ('settings-task-message-ask', TaskMessageMode.ask),
    ]) {
      final chip = find.byKey(Key(key));
      await tester.ensureVisible(chip);
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(preferences.taskMessageMode, mode, reason: key);
      expect(DevicePreferences(stored).taskMessageMode, mode);
    }

    expect(find.bySemanticsLabel('افتح واتساب مباشرة'), findsOneWidget);
    expect(api.calls, 0, reason: 'a phone choice, not the server\'s');
    expect(tester.takeException(), isNull);
  });
}

class _NoSettingsApi extends SettingsApi {
  _NoSettingsApi() : super(ApiClient(tokenProvider: () async => null));

  int calls = 0;

  @override
  Future<UserSettings> getSettings() async {
    calls += 1;
    throw StateError('not signed in');
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    calls += 1;
    return settings;
  }
}
