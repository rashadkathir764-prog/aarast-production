import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mobile displays dev OTP helper only for local dev responses', (
    tester,
  ) async {
    final authController = await _authController();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(
            phone: '+967777123456',
            purpose: 'VERIFY_PHONE',
            devOtpMessage: 'رمز التحقق مؤقت للتجربة المحلية: 123456',
          ),
        ),
      ),
    );

    expect(
      find.text('رمز التحقق مؤقت للتجربة المحلية: 123456'),
      findsOneWidget,
    );
  });

  testWidgets('mobile hides dev OTP helper for production OTP responses', (
    tester,
  ) async {
    final authController = await _authController();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const MaterialApp(
          home: OtpScreen(phone: '+967777123456', purpose: 'VERIFY_PHONE'),
        ),
      ),
    );

    expect(
      find.textContaining('رمز التحقق مؤقت للتجربة المحلية'),
      findsNothing,
    );
  });
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  return AuthController(authRepository);
}
