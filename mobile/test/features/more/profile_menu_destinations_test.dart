import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// g02 «حسابي» (D23): the account, the wedding, how the app looks, safety
// and privacy, and the account group C51 adds.
void main() {
  testWidgets('a guest sees the account screen with sign in, not sign out', (
    tester,
  ) async {
    final harness = await _MoreHarness.guest();

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);

    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('شكل التطبيق'), findsOneWidget);
    expect(find.text('التاريخ الهجري جنب الميلادي'), findsOneWidget);
    expect(find.text('خط كبير'), findsOneWidget);
    expect(find.text('توفير البيانات'), findsOneWidget);
    expect(find.text('أخفِ المبالغ'), findsOneWidget);
    // D23: no app-wide digit shaping, and no dark mode in this build (D6).
    expect(find.text('الأرقام'), findsNothing);
    expect(find.text('الوضع الليلي'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('تسجيل الدخول'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('الخروج'), findsNothing);
    expect(find.byTooltip('تعديل صورة الحساب'), findsNothing);
  });

  // Field test Q08: a guest saw "synced successfully" while the plan lived
  // only on the phone.
  testWidgets('a guest is not told their plan is synced', (tester) async {
    final harness = await _MoreHarness.guest(withSyncService: true);

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);

    expect(find.text('مزامنة الآن'), findsNothing);
    expect(find.text('تمت المزامنة بنجاح'), findsNothing);
  });

  testWidgets('the account keeps its photo change and sign out', (
    tester,
  ) async {
    final harness = await _MoreHarness.signedIn();

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);

    expect(find.text('رشاد'), findsOneWidget);
    expect(find.text('+967 777 000 000'), findsOneWidget);
    expect(find.byTooltip('تعديل صورة الحساب'), findsOneWidget);
    expect(find.text('تغيير رقم الجوال'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('الخروج'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    // C4: deleting the account stays hidden until its 30-day grace exists.
    expect(find.textContaining('حذف الحساب'), findsNothing);
    await tester.ensureVisible(find.text('الخروج'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('the look switches are kept on the phone', (tester) async {
    final harness = await _MoreHarness.guest();

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('account-large-text')),
        matching: find.byType(JourneyToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.preferences.largeText, isTrue);
  });
}

Future<void> _settleEntry(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

class _MoreHarness {
  const _MoreHarness({required this.widget, required this.preferences});

  final Widget widget;
  final DevicePreferences preferences;

  static Future<_MoreHarness> guest({bool withSyncService = false}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final authRepository = AuthRepository(
      ApiClient(tokenProvider: authStorage.readAccessToken),
      authStorage,
    );
    final authController = AuthController(authRepository);
    await authController.restoreSession();
    OfflineSyncService? syncService;
    if (withSyncService) {
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      syncService = OfflineSyncService(
        database: database,
        apiClient: ApiClient(tokenProvider: () async => null),
      );
      await syncService.refreshStatus();
    }
    final device = DevicePreferences(preferences);
    return _MoreHarness(
      preferences: device,
      widget: _buildApp(
        preferences: preferences,
        device: device,
        authStorage: authStorage,
        authRepository: authRepository,
        authController: authController,
        syncService: syncService,
      ),
    );
  }

  static Future<_MoreHarness> signedIn() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final authRepository = _SignedInAuthRepository(authStorage);
    final authController = AuthController(authRepository);
    await authController.restoreSession();
    final device = DevicePreferences(preferences);
    return _MoreHarness(
      preferences: device,
      widget: _buildApp(
        preferences: preferences,
        device: device,
        authStorage: authStorage,
        authRepository: authRepository,
        authController: authController,
      ),
    );
  }

  static Widget _buildApp({
    required SharedPreferences preferences,
    required DevicePreferences device,
    required AuthStorage authStorage,
    required AuthRepository authRepository,
    required AuthController authController,
    OfflineSyncService? syncService,
  }) {
    return MultiProvider(
      providers: [
        if (syncService != null)
          ChangeNotifierProvider<OfflineSyncService>.value(value: syncService),
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<GuestOnboardingStorage>.value(
          value: GuestOnboardingStorage(preferences),
        ),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<DevicePreferences>.value(value: device),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MoreScreen(),
        ),
      ),
    );
  }
}

class _SignedInAuthRepository extends AuthRepository {
  _SignedInAuthRepository(AuthStorage storage)
    : super(_NoopApiClient(), storage);

  static const _user = SafeUser(
    id: 'user-1',
    name: 'رشاد',
    phone: '+967777000000',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<SafeUser> me() async => _user;
}

class _NoopApiClient extends ApiClient {
  _NoopApiClient() : super(tokenProvider: () async => 'token');
}
