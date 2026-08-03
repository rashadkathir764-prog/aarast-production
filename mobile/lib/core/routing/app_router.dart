import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../diagnostics/app_logger.dart';
import '../../features/welcome_gateway/screens/smart_welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/account_contexts/widgets/wedding_plan_context_gate.dart';
import '../../features/account_contexts/models/account_context.dart';
import '../../features/account_contexts/providers/account_context_controller.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/quote_conversation_entry_screen.dart';
import '../../features/chat/widgets/conversation_list_view.dart';
import '../../features/finance/models/budget_category.dart';
import '../../features/finance/models/cost_draft_intent.dart';
import '../../features/finance/models/wedding_cost.dart';
import '../../features/finance/providers/finance_provider.dart';
import '../../features/finance/screens/budget_category_details_screen.dart';
import '../../features/finance/screens/budget_category_form_screen.dart';
import '../../features/finance/screens/cost_details_screen.dart';
import '../../features/finance/screens/cost_form_screen.dart';
import '../../features/finance/screens/cost_payment_screens.dart';
import '../../features/finance/screens/costs_screen.dart';
import '../../features/finance/screens/money_budget_screen.dart';
import '../../features/finance/screens/money_overview_screen.dart';
import '../../features/finance/screens/payment_schedule_screens.dart';
import '../../features/guests/screens/guest_list_screen.dart';
import '../../features/marketplace/screens/add_provider_package_screen.dart';
import '../../features/marketplace/screens/add_provider_service_screen.dart';
import '../../features/marketplace/screens/edit_provider_profile_screen.dart';
import '../../features/marketplace/screens/favorite_providers_screen.dart';
import '../../features/marketplace/screens/provider_apply_screen.dart';
import '../../features/marketplace/screens/provider_details_screen.dart';
import '../../features/marketplace/screens/provider_marketplace_screen.dart';
import '../../features/marketplace/screens/provider_portal_screen.dart';
import '../../features/marketplace/screens/quote_request_screen.dart';
import '../../features/marketplace/models/provider_budget_match_intent.dart';
import '../../features/marketplace/widgets/provider_auth_gate.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/sharing/screens/invite_decision_screen.dart';
import '../../features/home/screens/dashboard_entry_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/sharing/screens/add_shared_member_screen.dart';
import '../../features/sharing/screens/edit_shared_member_screen.dart';
import '../../features/sharing/screens/shared_wedding_plans_screen.dart';
import '../../features/sharing/screens/sharing_screen.dart';
import '../../features/sharing/screens/contribution_history_screen.dart';
import '../../features/sharing/models/shared_member.dart';
import '../../features/support/screens/support_screen.dart';
import '../../features/tasks/models/wedding_task.dart';
import '../../features/tasks/screens/create_task_screen.dart';
import '../../features/tasks/screens/task_timeline_screen.dart';
import '../../features/wedding_plans/screens/create_wedding_plan_screen.dart';
import '../../features/wedding_plans/screens/my_wedding_plans_screen.dart';

import '../../features/wedding_plans/models/dashboard_summary.dart';
import '../../features/wedding_plans/screens/plan_center_screen.dart';
import '../../features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../../features/shell/screens/wedding_plan_shell.dart';
import '../config/app_feature_flags.dart';

enum ProviderMarketplaceLaunchOrigin { ownerMainShellProviders }

@immutable
class ProviderMarketplaceRouteResult {
  const ProviderMarketplaceRouteResult.focusQuote(this.quoteId);

  final String quoteId;
}

class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const resetPassword = '/reset-password';
  static const otp = '/otp';
  static const home = '/home';
  static const weddingPlans = '/wedding-plans';
  static const createWeddingPlan = '/wedding-plans/create';
  static const providerMarketplace = '/providers';
  static const favoriteProviders = '/providers/favorites';
  static const conversations = '/conversations';
  static const providerApply = '/provider/apply';
  static const providerApplyStatus = '/provider/apply/status';
  static const providerDashboard = '/provider/dashboard';
  static const providerProfileEdit = '/provider/profile/edit';
  static const providerServiceNew = '/provider/services/new';
  static const providerPackageNew = '/provider/packages/new';
  static const notifications = '/notifications';
  static const inviteAccess = '/invites';
  static const inviteAppLinkHost = 'aarast.shadowgardn.com';
  static const inviteCustomSchemeHost = 'open';
  static String inviteDecision(String token) =>
      '/invites/${Uri.encodeComponent(token)}';
  static Uri inviteCustomLink(String token) => Uri(
    scheme: 'aarast',
    host: inviteCustomSchemeHost,
    pathSegments: ['invites', token],
  );
  static Uri inviteHttpsLink(String token) => Uri(
    scheme: 'https',
    host: inviteAppLinkHost,
    pathSegments: ['invites', token],
  );
  static const more = '/more';
  static const settings = '/settings';
  static const support = '/support';
  static const guestOnboardingPreview = '/dev/guest-onboarding';
  static const userNavigationShellPreview = '/dev/user-navigation-shell';

  static String authenticatedEntry(String? resumeLocation) {
    final resume = resumeLocation?.trim();
    if (resume == null ||
        resume.isEmpty ||
        !resume.startsWith('/') ||
        resume.startsWith('//') ||
        resume == home) {
      return home;
    }
    final uri = Uri.tryParse(resume);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return home;
    return Uri(path: home, queryParameters: {'resume': resume}).toString();
  }

  static String providerDetails(String id, {String? weddingPlanId}) {
    final planId = weddingPlanId?.trim();
    if (planId == null || planId.isEmpty) return '/providers/$id';
    return Uri(
      path: '/providers/$id',
      queryParameters: {'weddingPlanId': planId},
    ).toString();
  }

  static String conversation(String id) {
    return '/conversations/$id';
  }

  static String quoteConversation(String quoteRequestId) {
    return '/quotes/$quoteRequestId/conversation';
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

  static String money(String id) {
    return '/wedding-plans/$id/money';
  }

  static String moneyBudget(String id) {
    return '/wedding-plans/$id/money/budget';
  }

  static String moneyCategoryCreate(String id) {
    return '/wedding-plans/$id/money/categories/create';
  }

  static String moneyCategoryDetails(String planId, String categoryId) {
    return '/wedding-plans/$planId/money/categories/$categoryId';
  }

  static String moneyCategoryEdit(String planId, String categoryId) {
    return '/wedding-plans/$planId/money/categories/$categoryId/edit';
  }

  static String moneyCosts(String planId, {String? categoryId}) {
    return Uri(
      path: '/wedding-plans/$planId/money/costs',
      queryParameters: categoryId == null ? null : {'categoryId': categoryId},
    ).toString();
  }

  static String moneyCostCreate(String planId, {String? categoryId}) {
    return Uri(
      path: '/wedding-plans/$planId/money/costs/create',
      queryParameters: categoryId == null ? null : {'categoryId': categoryId},
    ).toString();
  }

  static String moneyCostEdit(String planId, String costId) {
    return '/wedding-plans/$planId/money/costs/$costId/edit';
  }

  static String moneyCostDetails(String planId, String costId) {
    return '/wedding-plans/$planId/money/costs/$costId';
  }

  static String moneyPaymentCreate(String planId, String costId) {
    return '/wedding-plans/$planId/money/costs/$costId/payments/create';
  }

  static String moneyPaymentDetails(
    String planId,
    String paymentId, {
    String? costId,
  }) {
    return Uri(
      path: '/wedding-plans/$planId/money/payments/$paymentId',
      queryParameters: costId == null ? null : {'costId': costId},
    ).toString();
  }

  static String moneySchedules(String planId, {String? costId}) {
    return Uri(
      path: '/wedding-plans/$planId/money/schedules',
      queryParameters: costId == null ? null : {'costId': costId},
    ).toString();
  }

  static String moneyScheduleCreate(String planId, String costId) {
    return '/wedding-plans/$planId/money/costs/$costId/schedules/create';
  }

  static String moneyScheduleDetails(
    String planId,
    String costId,
    String scheduleId,
  ) {
    return '/wedding-plans/$planId/money/costs/$costId/schedules/$scheduleId';
  }

  static String moneyScheduleEdit(
    String planId,
    String costId,
    String scheduleId,
  ) {
    return '/wedding-plans/$planId/money/costs/$costId/schedules/$scheduleId/edit';
  }

  static String moneySchedulePay(
    String planId,
    String costId,
    String scheduleId,
  ) {
    return '/wedding-plans/$planId/money/costs/$costId/schedules/$scheduleId/pay';
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

  static String guestListAdd(String id) {
    return '/wedding-plans/$id/guests/add';
  }

  static String planProviders(String id, {String? quoteId}) {
    final normalizedQuoteId = quoteId?.trim();
    if (normalizedQuoteId == null || normalizedQuoteId.isEmpty) {
      return '/wedding-plans/$id/providers';
    }
    return Uri(
      path: '/wedding-plans/$id/providers',
      queryParameters: {'quoteId': normalizedQuoteId},
    ).toString();
  }

  static String planNotifications(String id) {
    return '/wedding-plans/$id/notifications';
  }

  static String contributionHistory(String id) {
    return '/wedding-plans/$id/contributions';
  }

  static String addSharedMember(String id) {
    return '/wedding-plans/$id/sharing/add';
  }

  static String editSharedMember(String weddingPlanId, String memberId) {
    return '/wedding-plans/$weddingPlanId/sharing/$memberId/edit';
  }

  static const sharedWeddingPlans = '/shared/wedding-plans';

  static String? guestOnboardingRedirect(AppFeatureFlags flags) {
    if (flags.enableGuestFirstOnboarding) return null;
    return onboarding;
  }

  static GoRouter create({AppFeatureFlags flags = AppFeatureFlags.defaults}) {
    return GoRouter(
      initialLocation: splash,
      errorBuilder: (context, state) {
        final safeLocation = safeRouterErrorLocation(state.uri);
        appLogEvent(
          'ROUTE_BLOCKED',
          category: AppLogCategory.navigation,
          targetRoute: safeLocation,
          reason: 'router_error',
          source: 'GoRouter.errorBuilder',
        );
        return RouterErrorScreen(error: state.error, location: safeLocation);
      },
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: welcome,
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        // The smart welcome gateway is the single onboarding truth. Legacy
        // paths stay registered so old deep links keep working.
        GoRoute(
          path: onboarding,
          redirect: (context, state) => welcome,
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        GoRoute(
          path: guestOnboardingPreview,
          redirect: (context, state) => guestOnboardingRedirect(flags),
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) =>
              LoginScreen(initialPhone: state.uri.queryParameters['phone']),
        ),
        GoRoute(
          path: register,
          builder: (context, state) => RegisterScreen(
            startAsProvider: state.uri.queryParameters['type'] == 'provider',
            initialPhone: state.uri.queryParameters['phone'],
          ),
        ),
        GoRoute(
          path: resetPassword,
          builder: (context, state) => ResetPasswordScreen(
            initialPhone: state.uri.queryParameters['phone'],
          ),
        ),
        GoRoute(
          path: otp,
          builder: (context, state) {
            final args = state.extra is OtpScreenArgs
                ? state.extra! as OtpScreenArgs
                : null;
            return OtpScreen(
              phone: args?.phone,
              purpose: args?.purpose,
              otpNoticeMessage: args?.otpNoticeMessage,
              registration: args?.registration,
              successLocation: args?.successLocation,
            );
          },
        ),
        GoRoute(
          path: home,
          builder: (context, state) => const DashboardEntryScreen(),
        ),
        // Public provider browsing: guests may open the marketplace and
        // provider details without an account. Quote/provider management
        // routes stay behind ProviderAuthGate.
        GoRoute(
          path: providerMarketplace,
          builder: (context, state) => ProviderMarketplaceScreen(
            initialQuoteId: state.uri.queryParameters['quoteId'],
          ),
        ),
        GoRoute(
          path: favoriteProviders,
          builder: (context, state) => const FavoriteProvidersScreen(),
        ),
        GoRoute(
          path: '/providers/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final weddingPlanId = state.uri.queryParameters['weddingPlanId'];
            final screen = ProviderDetailsScreen(
              providerId: id,
              weddingPlanId: weddingPlanId,
              returnQuoteToMarketplace:
                  state.extra ==
                  ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
            );
            return weddingPlanId == null
                ? screen
                : WeddingPlanContextGate(
                    weddingPlanId: weddingPlanId,
                    requiredAccess: WeddingPlanRouteAccess.manageProviders,
                    child: screen,
                  );
          },
        ),
        GoRoute(
          path: '/providers/:id/quote',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final quoteContext = state.extra is ProviderQuoteInitialContext
                ? state.extra! as ProviderQuoteInitialContext
                : null;
            final initialServiceId =
                quoteContext?.serviceId ??
                (state.extra is String ? state.extra! as String : null);
            return ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              child: SelectedWeddingPlanContextGate(
                requiredAccess: WeddingPlanRouteAccess.manageProviders,
                child: QuoteRequestScreen(
                  providerId: id,
                  initialServiceId: initialServiceId,
                  initialBudgetIntent: quoteContext?.budgetIntent,
                ),
              ),
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
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            child: const ProviderApplyScreen(),
          ),
        ),
        GoRoute(
          path: providerApplyStatus,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            child: const ProviderApplyStatusScreen(),
          ),
        ),
        GoRoute(
          path: providerDashboard,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            providerAccountRequired: true,
            child: const ProviderPortalScreen(),
          ),
        ),
        GoRoute(
          path: providerProfileEdit,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            providerAccountRequired: true,
            providerProfileManageRequired: true,
            child: const EditProviderProfileScreen(),
          ),
        ),
        GoRoute(
          path: providerServiceNew,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            providerAccountRequired: true,
            providerOperationsRequired: true,
            child: const AddProviderServiceScreen(),
          ),
        ),
        GoRoute(
          path: providerPackageNew,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            registerAsProvider: true,
            providerAccountRequired: true,
            providerOperationsRequired: true,
            child: const AddProviderPackageScreen(),
          ),
        ),
        // Secure quote chat: every list, detail, and quote entry route requires
        // a real account. Backend ownership still limits each conversation to
        // the requester and the provider attached to that quote request.
        GoRoute(
          path: conversations,
          builder: (context, state) => ProviderAuthGate(
            resumeLocation: state.uri.toString(),
            child: const ConversationListView(),
          ),
        ),
        GoRoute(
          path: '/conversations/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              child: ChatScreen(conversationId: id),
            );
          },
        ),
        GoRoute(
          path: '/quotes/:id/conversation',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ProviderAuthGate(
              resumeLocation: state.uri.toString(),
              child: QuoteConversationEntryScreen(
                quoteRequestId: id,
                returnQuoteToMarketplace:
                    state.extra ==
                    ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
              ),
            );
          },
        ),
        GoRoute(
          path: notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: inviteAccess,
          builder: (context, state) => const InviteDecisionScreen(),
        ),
        GoRoute(
          path: '/invites/:token',
          builder: (context, state) =>
              InviteDecisionScreen(token: state.pathParameters['token'] ?? ''),
        ),
        GoRoute(path: more, builder: (context, state) => const MoreScreen()),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: support,
          builder: (context, state) => const SupportScreen(),
        ),
        GoRoute(
          path: weddingPlans,
          builder: (context, state) => const MyWeddingPlansScreen(),
        ),
        GoRoute(
          path: createWeddingPlan,
          builder: (context, state) => const CreateWeddingPlanScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: weddingPlanRouteAccessForPath(state.uri.path),
              child: WeddingPlanShell(weddingPlanId: id, child: child),
            );
          },
          routes: [
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
                  embedded: true,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final sharedMember = state.extra is SharedMember
                    ? state.extra! as SharedMember
                    : null;
                final selected = context
                    .read<AccountContextController?>()
                    ?.selectedContext;
                final contributorView =
                    selected?.role == AccountContextRole.contributor &&
                    selected?.weddingPlanId == id;
                return MoneyOverviewScreen(
                  weddingPlanId: id,
                  sharedMember: sharedMember,
                  embedded: !contributorView,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/budget',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return MoneyBudgetScreen(weddingPlanId: id);
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/categories/create',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return BudgetCategoryFormScreen(
                  weddingPlanId: id,
                  initialName: state.extra is String
                      ? state.extra! as String
                      : null,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/categories/:categoryId',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final categoryId = state.pathParameters['categoryId'] ?? '';
                return BudgetCategoryDetailsScreen(
                  weddingPlanId: id,
                  categoryId: categoryId,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/categories/:categoryId/edit',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final categoryId = state.pathParameters['categoryId'] ?? '';
                final category = state.extra is BudgetCategory
                    ? state.extra! as BudgetCategory
                    : context.read<FinanceProvider>().categoryById(categoryId);
                if (category == null) {
                  return BudgetCategoryDetailsScreen(
                    weddingPlanId: id,
                    categoryId: categoryId,
                  );
                }
                return BudgetCategoryFormScreen(
                  weddingPlanId: id,
                  category: category,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return CostsScreen(
                  weddingPlanId: id,
                  initialCategoryId: state.uri.queryParameters['categoryId'],
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs/create',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return CostFormScreen(
                  weddingPlanId: id,
                  intent: state.extra is CostDraftIntent
                      ? state.extra! as CostDraftIntent
                      : null,
                  initialCategoryId: state.uri.queryParameters['categoryId'],
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs/:costId/edit',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final costId = state.pathParameters['costId'] ?? '';
                final cost = state.extra is WeddingCost
                    ? state.extra! as WeddingCost
                    : context.read<FinanceProvider>().costById(costId);
                if (cost == null) {
                  return CostsScreen(weddingPlanId: id);
                }
                return CostFormScreen(weddingPlanId: id, cost: cost);
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs/:costId/payments/create',
              builder: (context, state) {
                return RecordCostPaymentScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/payments/:paymentId',
              builder: (context, state) {
                return CostPaymentDetailsScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.uri.queryParameters['costId'],
                  paymentId: state.pathParameters['paymentId'] ?? '',
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/schedules',
              builder: (context, state) {
                return PaymentSchedulesScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.uri.queryParameters['costId'],
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs/:costId/schedules/create',
              builder: (context, state) {
                return PaymentScheduleFormScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                );
              },
            ),
            GoRoute(
              path:
                  '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/edit',
              builder: (context, state) {
                return PaymentScheduleFormScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                  scheduleId: state.pathParameters['scheduleId'] ?? '',
                );
              },
            ),
            GoRoute(
              path:
                  '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/pay',
              builder: (context, state) {
                return PayPaymentScheduleScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                  scheduleId: state.pathParameters['scheduleId'] ?? '',
                );
              },
            ),
            GoRoute(
              path:
                  '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
              builder: (context, state) {
                return PaymentScheduleDetailsScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                  scheduleId: state.pathParameters['scheduleId'] ?? '',
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/money/costs/:costId',
              builder: (context, state) {
                return CostDetailsScreen(
                  weddingPlanId: state.pathParameters['id'] ?? '',
                  costId: state.pathParameters['costId'] ?? '',
                );
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
              path: '/wedding-plans/:id/guests/add',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return GuestListScreen(
                  weddingPlanId: id,
                  showLocalFab: false,
                  openAddOnStart: true,
                );
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/guests',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return GuestListScreen(weddingPlanId: id, showLocalFab: false);
              },
            ),
            GoRoute(
              path: '/wedding-plans/:id/providers',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final budgetIntent = state.extra is ProviderBudgetMatchIntent
                    ? state.extra! as ProviderBudgetMatchIntent
                    : null;
                return ProviderMarketplaceScreen(
                  embedded:
                      context
                          .read<AccountContextController?>()
                          ?.selectedContext
                          ?.role !=
                      AccountContextRole.contributor,
                  weddingPlanId: id,
                  initialBudgetIntent: budgetIntent,
                  initialQuoteId: state.uri.queryParameters['quoteId'],
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/wedding-plans/:id/plan-center',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final sharedMember = state.extra is SharedMember
                ? state.extra! as SharedMember
                : (state.extra is Map &&
                      (state.extra as Map)['sharedMember'] is SharedMember)
                ? (state.extra as Map)['sharedMember'] as SharedMember
                : null;
            final initialSummary =
                state.extra is Map &&
                    (state.extra as Map)['summary'] is DashboardSummary
                ? (state.extra as Map)['summary'] as DashboardSummary
                : null;
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.viewPlan,
              child: PlanCenterScreen(
                weddingPlanId: id,
                sharedMember: sharedMember,
                initialSummary: initialSummary,
              ),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/tasks/create',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.manageTasks,
              child: CreateTaskScreen(weddingPlanId: id),
            );
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
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.manageTasks,
              child: CreateTaskScreen(
                weddingPlanId: id,
                taskId: taskId,
                initialTask: task,
              ),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/timeline',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.manageTasks,
              child: TaskTimelineScreen(weddingPlanId: id),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.inviteMembers,
              child: SharingScreen(weddingPlanId: id),
            );
          },
        ),

        GoRoute(
          path: '/wedding-plans/:id/notifications',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.viewPlan,
              child: NotificationsScreen(weddingPlanId: id),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/contributions',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.viewPlan,
              child: ContributionHistoryScreen(weddingPlanId: id),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing/add',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.inviteMembers,
              child: AddSharedMemberScreen(weddingPlanId: id),
            );
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/sharing/:memberId/edit',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final memberId = state.pathParameters['memberId'] ?? '';
            return WeddingPlanContextGate(
              weddingPlanId: id,
              requiredAccess: WeddingPlanRouteAccess.inviteMembers,
              child: EditSharedMemberScreen(sharedMemberId: memberId),
            );
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

WeddingPlanRouteAccess weddingPlanRouteAccessForPath(String path) {
  final segments = Uri.tryParse(path)?.pathSegments ?? const <String>[];
  if (segments.length < 3 || segments.first != 'wedding-plans') {
    return WeddingPlanRouteAccess.unknown;
  }

  final section = segments[2];
  return switch (section) {
    'dashboard' => WeddingPlanRouteAccess.ownerDashboard,
    'plan-center' ||
    'notifications' ||
    'contributions' => WeddingPlanRouteAccess.viewPlan,
    'timeline' || 'tasks' => WeddingPlanRouteAccess.manageTasks,
    'guests' => WeddingPlanRouteAccess.manageGuests,
    'providers' => WeddingPlanRouteAccess.manageProviders,
    'sharing' => WeddingPlanRouteAccess.inviteMembers,
    'money' =>
      _isReadOnlyMoneyPath(segments)
          ? WeddingPlanRouteAccess.viewMoney
          : WeddingPlanRouteAccess.manageMoney,
    _ => WeddingPlanRouteAccess.unknown,
  };
}

bool _isReadOnlyMoneyPath(List<String> segments) {
  if (segments.length == 3) return true;
  final mutationMarkers = {'create', 'edit', 'pay'};
  return !segments.any(mutationMarkers.contains);
}

@visibleForTesting
String safeRouterErrorLocation(Uri uri) {
  if (uri.pathSegments.isEmpty) return '/';
  return '/${uri.pathSegments.first}';
}

/// Visible router boundary for unknown routes and route-construction failures.
/// It deliberately offers an explicit escape to the welcome/selection flow
/// and never selects a context or redirects implicitly.
class RouterErrorScreen extends StatelessWidget {
  const RouterErrorScreen({
    required this.error,
    required this.location,
    super.key,
  });

  final Exception? error;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('router-error-boundary'),
      appBar: AppBar(title: const Text('تعذر فتح الصفحة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.navigation, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ في مسار التنقل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'لم نغيّر مسار الحساب تلقائيًا. عد إلى اختيار المسار وحاول مرة أخرى.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('router-error-home-button'),
                  onPressed: () => context.go(AppRouter.home),
                  child: const Text('العودة إلى اختيار المسار'),
                ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'المسار: $location',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
