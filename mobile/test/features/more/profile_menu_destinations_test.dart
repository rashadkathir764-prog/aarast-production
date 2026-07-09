import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guest profile menu shows login instead of logout', (
    tester,
  ) async {
    final harness = await _MoreHarness.guest();

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);

    expect(find.text('خطط الزفاف'), findsOneWidget);
    expect(find.text('خططي'), findsOneWidget);
    expect(find.text('الخطط المشتركة معي'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('المزامنة'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('المزامنة'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('تسجيل الدخول'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsNothing);
    expect(find.byTooltip('تعديل صورة الحساب'), findsNothing);
  });

  testWidgets('account-backed profile menu keeps logout action', (
    tester,
  ) async {
    final harness = await _MoreHarness.signedIn();

    await tester.pumpWidget(harness.widget);
    await _settleEntry(tester);

    expect(find.byTooltip('تعديل صورة الحساب'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('تسجيل الخروج'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('تسجيل الخروج'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });
}

Future<void> _settleEntry(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

class _MoreHarness {
  const _MoreHarness({required this.widget});

  final Widget widget;

  static Future<_MoreHarness> guest() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final authRepository = AuthRepository(
      ApiClient(tokenProvider: authStorage.readAccessToken),
      authStorage,
    );
    final authController = AuthController(authRepository);
    await authController.restoreSession();
    return _MoreHarness(
      widget: _buildApp(
        preferences: preferences,
        authStorage: authStorage,
        authRepository: authRepository,
        authController: authController,
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
    return _MoreHarness(
      widget: _buildApp(
        preferences: preferences,
        authStorage: authStorage,
        authRepository: authRepository,
        authController: authController,
      ),
    );
  }

  static Widget _buildApp({
    required SharedPreferences preferences,
    required AuthStorage authStorage,
    required AuthRepository authRepository,
    required AuthController authController,
  }) {
    return MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<GuestOnboardingStorage>.value(
          value: GuestOnboardingStorage(preferences),
        ),
        ChangeNotifierProvider<AuthController>.value(value: authController),
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
