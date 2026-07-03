import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('profile menu destination keeps valid old More entries', (
    tester,
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
          Provider<GuestOnboardingStorage>.value(
            value: GuestOnboardingStorage(preferences),
          ),
          ChangeNotifierProvider<AuthController>.value(value: authController),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const MoreScreen()),
      ),
    );

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('خطط الزفاف'), findsOneWidget);
    expect(find.text('خططي'), findsOneWidget);
    expect(find.text('الخطط المشتركة معي'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('الحساب والمساعدة'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الحساب والمساعدة'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('الإعدادات'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('الدعم والمساعدة'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('المزامنة'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('المزامنة'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('تسجيل الخروج'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });
}
