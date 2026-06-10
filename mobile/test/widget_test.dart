import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('shows Arabic login screen when no token is stored', (
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

    expect(find.text('أعرست'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsAtLeastNWidgets(1));
    expect(find.text('رقم الهاتف'), findsOneWidget);
  });
}
