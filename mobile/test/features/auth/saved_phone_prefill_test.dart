import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/phone/yemeni_phone_normalizer.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/provider_register_screen.dart';
import 'package:aarast_mobile/features/auth/screens/register_screen.dart';
import 'package:aarast_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const savedPhone = '+967777000101';
  final forms = <String, Widget>{
    'expired login': const LoginScreen(
      initialPhone: savedPhone,
      sessionExpired: true,
    ),
    'registration': const RegisterScreen(initialPhone: savedPhone),
    'provider registration': const ProviderRegisterScreen(
      initialPhone: savedPhone,
    ),
    'password recovery': const ResetPasswordScreen(initialPhone: savedPhone),
  };

  for (final form in forms.entries) {
    testWidgets('${form.key} presents the saved country code only once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      final auth = AuthController(
        AuthRepository(
          ApiClient(tokenProvider: storage.readAccessToken),
          storage,
        ),
      );
      final offline = _NoPendingChanges();
      addTearDown(auth.dispose);
      addTearDown(offline.dispose);
      final router = GoRouter(
        initialLocation: '/subject',
        routes: [GoRoute(path: '/subject', builder: (_, _) => form.value)],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byType(JourneyPhoneField),
        matching: find.byType(EditableText),
      );
      expect(field, findsOneWidget);
      final input = tester.widget<EditableText>(field);
      expect(input.controller.text, '777 000 101');
      expect(find.text('+967'), findsOneWidget);
      expect(normalizeYemeniPhone(input.controller.text), savedPhone);
      expect(Directionality.of(tester.element(field)), TextDirection.ltr);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _NoPendingChanges extends ChangeNotifier implements OfflineSyncService {
  @override
  int get pendingCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
