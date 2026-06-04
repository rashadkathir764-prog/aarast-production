import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/wedding_plans/screens/create_wedding_plan_screen.dart';
import '../../features/wedding_plans/screens/my_wedding_plans_screen.dart';
import '../../features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';

class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const weddingPlans = '/wedding-plans';
  static const createWeddingPlan = '/wedding-plans/create';

  static String weddingPlanDashboard(String id) {
    return '/wedding-plans/$id/dashboard';
  }

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
        GoRoute(
          path: weddingPlans,
          builder: (context, state) => const MyWeddingPlansScreen(),
        ),
        GoRoute(
          path: createWeddingPlan,
          builder: (context, state) => const CreateWeddingPlanScreen(),
        ),
        GoRoute(
          path: '/wedding-plans/:id/dashboard',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanDashboardScreen(weddingPlanId: id);
          },
        ),
      ],
    );
  }
}
