import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';

class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';

  static GoRouter create() {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(path: home, builder: (context, state) => const HomeScreen()),
      ],
    );
  }
}
