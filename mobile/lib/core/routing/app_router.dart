import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/screens/guest_onboarding_flow_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/debts/screens/create_debt_screen.dart';
import '../../features/debts/screens/create_installment_screen.dart';
import '../../features/debts/screens/debt_details_screen.dart';
import '../../features/debts/screens/debt_installment_screen.dart';
import '../../features/finance/screens/budget_expense_screen.dart';
import '../../features/finance/screens/create_budget_category_screen.dart';
import '../../features/finance/screens/create_expense_screen.dart';
import '../../features/finance/models/expense.dart';
import '../../features/guests/screens/guest_list_screen.dart';
import '../../features/marketplace/screens/add_provider_package_screen.dart';
import '../../features/marketplace/screens/add_provider_service_screen.dart';
import '../../features/marketplace/screens/provider_apply_screen.dart';
import '../../features/marketplace/screens/provider_dashboard_screen.dart';
import '../../features/marketplace/screens/provider_details_screen.dart';
import '../../features/marketplace/screens/provider_marketplace_screen.dart';
import '../../features/marketplace/screens/quote_request_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/sharing/screens/add_shared_member_screen.dart';
import '../../features/sharing/screens/edit_shared_member_screen.dart';
import '../../features/sharing/screens/shared_wedding_plans_screen.dart';
import '../../features/sharing/screens/sharing_screen.dart';
import '../../features/sharing/models/shared_member.dart';
import '../../features/tasks/models/wedding_task.dart';
import '../../features/tasks/screens/create_task_screen.dart';
import '../../features/tasks/screens/task_timeline_screen.dart';
import '../../features/wedding_plans/screens/create_wedding_plan_screen.dart';
import '../../features/wedding_plans/screens/my_wedding_plans_screen.dart';
import '../../features/wedding_plans/screens/plan_center_screen.dart';
import '../../features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../config/app_feature_flags.dart';
import '../widgets/coming_soon_screen.dart';

class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const home = '/home';
  static const weddingPlans = '/wedding-plans';
  static const createWeddingPlan = '/wedding-plans/create';
  static const providerMarketplace = '/providers';
  static const providerApply = '/provider/apply';
  static const providerApplyStatus = '/provider/apply/status';
  static const providerDashboard = '/provider/dashboard';
  static const legacyProviderDashboard = '/provider-dashboard';
  static const providerServiceNew = '/provider/services/new';
  static const providerPackageNew = '/provider/packages/new';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const support = '/support';
  static const guestOnboardingPreview = '/dev/guest-onboarding';

  static String providerDetails(String id) {
    return '/providers/$id';
  }

  static String providerQuoteRequest(String id) {
    return '/providers/$id/quote-request';
  }

  static String providerQuote(String id) {
    return '/providers/$id/quote';
  }

  static String weddingPlanDashboard(String id) {
    return '/wedding-plans/$id/dashboard';
  }

  static String planCenter(String id) {
    return '/wedding-plans/$id/plan-center';
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

  static String editExpense(String weddingPlanId, String expenseId) {
    return '/wedding-plans/$weddingPlanId/expenses/$expenseId/edit';
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

  static String editTask(String weddingPlanId, String taskId) {
    return '/wedding-plans/$weddingPlanId/tasks/$taskId/edit';
  }

  static String timeline(String id) {
    return '/wedding-plans/$id/timeline';
  }

  static String sharing(String id) {
    return '/wedding-plans/$id/sharing';
  }

  static String guestList(String id) {
    return '/wedding-plans/$id/guests';
  }

  static String planNotifications(String id) {
    return '/wedding-plans/$id/notifications';
  }

  static String addSharedMember(String id) {
    return '/wedding-plans/$id/sharing/add';
  }

  static String editSharedMember(String id) {
    return '/shared-members/$id/edit';
  }

  static const sharedWeddingPlans = '/shared/wedding-plans';

  static String? guestOnboardingRedirect(AppFeatureFlags flags) {
    return flags.enableGuestFirstOnboarding ? null : onboarding;
  }

  static GoRouter create() {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: guestOnboardingPreview,
          redirect: (context, state) {
            return guestOnboardingRedirect(AppFeatureFlags.defaults);
          },
          builder: (context, state) => const GuestOnboardingFlowScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: register,
          builder: (context, state) => RegisterScreen(
            startAsProvider: state.uri.queryParameters['type'] == 'provider',
          ),
        ),
        GoRoute(path: otp, builder: (context, state) => const OtpScreen()),
        GoRoute(path: home, builder: (context, state) => const MainShell()),
        GoRoute(
          path: providerMarketplace,
          builder: (context, state) => const ProviderMarketplaceScreen(),
        ),
        GoRoute(
          path: '/providers/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ProviderDetailsScreen(providerId: id);
          },
        ),
        GoRoute(
          path: '/providers/:id/quote',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final initialServiceId = state.extra is String
                ? state.extra! as String
                : null;
            return QuoteRequestScreen(
              providerId: id,
              initialServiceId: initialServiceId,
            );
          },
        ),
        GoRoute(
          path: '/providers/:id/quote-request',
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return providerQuote(id);
          },
        ),
        GoRoute(
          path: providerApply,
          builder: (context, state) => const ProviderApplyScreen(),
        ),
        GoRoute(
          path: providerApplyStatus,
          builder: (context, state) => const ProviderApplyStatusScreen(),
        ),
        GoRoute(
          path: providerDashboard,
          builder: (context, state) => const ProviderDashboardScreen(),
        ),
        GoRoute(
          path: legacyProviderDashboard,
          redirect: (context, state) => providerDashboard,
        ),
        GoRoute(
          path: providerServiceNew,
          builder: (context, state) => const AddProviderServiceScreen(),
        ),
        GoRoute(
          path: providerPackageNew,
          builder: (context, state) => const AddProviderPackageScreen(),
        ),
        GoRoute(
          path: notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: support,
          builder: (context, state) => const AarastComingSoonScreen(
            title: 'الدعم والمساعدة',
            message:
                'قناة الدعم ستظهر هنا عند اعتماد تجربة التواصل والأسئلة الشائعة.',
            icon: Icons.support_agent_outlined,
          ),
        ),
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
            final sharedMember = state.extra is SharedMember
                ? state.extra! as SharedMember
                : null;
            return WeddingPlanDashboardScreen(
              weddingPlanId: id,
              sharedMember: sharedMember,
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/plan-center',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final sharedMember = state.extra is SharedMember
                ? state.extra! as SharedMember
                : null;
            return PlanCenterScreen(
              weddingPlanId: id,
              sharedMember: sharedMember,
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/finance',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final sharedMember = state.extra is SharedMember
                ? state.extra! as SharedMember
                : null;
            return BudgetExpenseScreen(
              weddingPlanId: id,
              sharedMember: sharedMember,
            );
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
          path: '/wedding-plans/:id/expenses/:expenseId/edit',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final expenseId = state.pathParameters['expenseId'] ?? '';
            final expense = state.extra is Expense
                ? state.extra! as Expense
                : null;
            return CreateExpenseScreen(
              weddingPlanId: id,
              expenseId: expenseId,
              initialExpense: expense,
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/debts',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final sharedMember = state.extra is SharedMember
                ? state.extra! as SharedMember
                : null;
            return DebtInstallmentScreen(
              weddingPlanId: id,
              sharedMember: sharedMember,
            );
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
          path: '/wedding-plans/:id/tasks/:taskId/edit',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final taskId = state.pathParameters['taskId'] ?? '';
            final task = state.extra is WeddingTask
                ? state.extra! as WeddingTask
                : null;
            return CreateTaskScreen(
              weddingPlanId: id,
              taskId: taskId,
              initialTask: task,
            );
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
          path: '/wedding-plans/:id/guests',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return GuestListScreen(weddingPlanId: id);
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/notifications',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return NotificationsScreen(weddingPlanId: id);
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
