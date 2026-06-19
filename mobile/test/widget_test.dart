import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows Arabic onboarding gate when no token is stored', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = AuthRepository(apiClient, storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: storage),
          Provider<ApiClient>.value(value: apiClient),
          Provider<AuthRepository>.value(value: repository),
          ChangeNotifierProvider(
            create: (_) => AuthController(repository)..restoreSession(),
          ),
        ],
        child: const AarastApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ألف مبروك!'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب'), findsOneWidget);
  });
}
