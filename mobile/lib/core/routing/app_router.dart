import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/debts/screens/create_debt_screen.dart';
import '../../features/debts/screens/create_installment_screen.dart';
import '../../features/debts/screens/debt_details_screen.dart';
import '../../features/debts/screens/debt_installment_screen.dart';
import '../../features/finance/screens/budget_expense_screen.dart';
import '../../features/finance/screens/create_budget_category_screen.dart';
import '../../features/finance/screens/create_expense_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/sharing/screens/add_shared_member_screen.dart';
import '../../features/sharing/screens/edit_shared_member_screen.dart';
import '../../features/sharing/screens/shared_wedding_plans_screen.dart';
import '../../features/sharing/screens/sharing_screen.dart';
import '../../features/tasks/screens/create_task_screen.dart';
import '../../features/tasks/screens/task_timeline_screen.dart';
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

  static String finance(String id) {
    return '/wedding-plans/$id/finance';
  }

  static String createBudgetCategory(String id) {
    return '/wedding-plans/$id/budget-categories/create';
  }

  static String createExpense(String id) {
    return '/wedding-plans/$id/expenses/create';
  }

  static String debts(String id) {
    return '/wedding-plans/$id/debts';
  }

  static String createDebt(String id) {
    return '/wedding-plans/$id/debts/create';
  }

  static String debtDetails(String debtId) {
    return '/debts/$debtId';
  }

  static String createInstallment(String debtId) {
    return '/debts/$debtId/installments/create';
  }

  static String tasks(String id) {
    return '/wedding-plans/$id/tasks';
  }

  static String createTask(String id) {
    return '/wedding-plans/$id/tasks/create';
  }

  static String timeline(String id) {
    return '/wedding-plans/$id/timeline';
  }

  static String sharing(String id) {
    return '/wedding-plans/$id/sharing';
  }

  static String addSharedMember(String id) {
    return '/wedding-plans/$id/sharing/add';
  }

  static String editSharedMember(String id) {
    return '/shared-members/$id/edit';
  }

  static const sharedWeddingPlans = '/shared/wedding-plans';

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
        GoRoute(
          path: '/wedding-plans/:id/finance',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return BudgetExpenseScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/budget-categories/create',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CreateBudgetCategoryScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/expenses/create',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CreateExpenseScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/debts',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return DebtInstallmentScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/debts/create',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CreateDebtScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/debts/:debtId',
          builder: (context, state) {
            final debtId = state.pathParameters['debtId'] ?? '';
            return DebtDetailsScreen(debtId: debtId);
          },
        ),
        GoRoute(
          path: '/debts/:debtId/installments/create',
          builder: (context, state) {
            final debtId = state.pathParameters['debtId'] ?? '';
            return CreateInstallmentScreen(debtId: debtId);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/tasks',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return TaskTimelineScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/tasks/create',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CreateTaskScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/timeline',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return TaskTimelineScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return SharingScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing/add',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AddSharedMemberScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/shared-members/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return EditSharedMemberScreen(sharedMemberId: id);
          },
        ),
        GoRoute(
          path: sharedWeddingPlans,
          builder: (context, state) => const SharedWeddingPlansScreen(),
        ),
      ],
    );
  }
}
