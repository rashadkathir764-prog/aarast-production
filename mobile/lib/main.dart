import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/auth_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/wedding_plans/data/wedding_plans_api.dart';
import 'features/wedding_plans/providers/wedding_plans_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final weddingPlansApi = WeddingPlansApi(apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<WeddingPlansApi>.value(value: weddingPlansApi),
        ChangeNotifierProvider(
          create: (_) => AuthController(authRepository)..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => WeddingPlansProvider(weddingPlansApi),
        ),
      ],
      child: const AarastApp(),
    ),
  );
}
