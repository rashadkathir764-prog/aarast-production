import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/auth_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider(
          create: (_) => AuthController(authRepository)..restoreSession(),
        ),
      ],
      child: const AarastApp(),
    ),
  );
}
