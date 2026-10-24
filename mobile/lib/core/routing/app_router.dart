import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../diagnostics/app_logger.dart';
import '../../features/account_contexts/account_contexts_api.dart'
    show
        AccountContextController,
        AccountContextRole,
        SelectedWeddingPlanContextGate,
        WeddingPlanContextGate,
        WeddingPlanRouteAccess;
import '../../features/auth/auth_api.dart'
    show
        LoginScreen,
        OtpScreen,
        OtpScreenArgs,
        RegisterScreen,
        ResetPasswordScreen,
        SplashScreen;
import '../../features/chat/chat_api.dart'
    show ChatScreen, ConversationListView, QuoteConversationEntryScreen;
import '../../features/finance/finance_api.dart'
    show
        BudgetCategory,
        BudgetCategoryDetailsScreen,
        BudgetCategoryFormScreen,
        CostDetailsScreen,
        CostDraftIntent,
        CostFormScreen,
        CostPaymentDetailsScreen,
        CostsScreen,
        FinanceProvider,
        FundingSourcesScreen,
        MoneyBudgetScreen,
        MoneyOverviewScreen,
        MoneyReceiptsScreen,
        PayPaymentScheduleScreen,
        PaymentScheduleDetailsScreen,
        PaymentScheduleFormScreen,
        PaymentSchedulesScreen,
        RecordCostPaymentScreen,
        WeddingCost;
import '../../features/guests/guests_api.dart'
    show
        GuestDetailsScreen,
        GuestImportScreen,
        GuestImportSource,
        GuestInviteScreen,
        GuestListScreen;
import '../../features/home/home_api.dart' show DashboardEntryScreen;
import '../../features/marketplace/marketplace_api.dart'
    show
        FavoriteProvidersScreen,
        ProviderAuthGate,
        ProviderBudgetMatchIntent,
        ProviderDetailsScreen,
        ProviderMarketplaceScreen,
        ProviderQuoteInitialContext,
        ProviderRequestsScreen,
        QuoteRequestScreen,
        providerRespondsLine;
import '../../features/more/more_api.dart' show MoreScreen;
import '../../features/notifications/notifications_api.dart'
    show NotificationsScreen;
import '../../features/provider_portal/provider_portal_api.dart'
    show
        AddProviderPackageScreen,
        AddProviderServiceScreen,
        EditProviderProfileScreen,
        ProviderApplyScreen,
        ProviderApplyStatusScreen,
        ProviderPortalScreen;
import '../../features/settings/settings_api.dart' show SettingsScreen;
import '../../features/sharing/sharing_api.dart'
    show
        AddSharedMemberScreen,
        ContributionHistoryScreen,
        EditSharedMemberScreen,
        InviteDecisionScreen,
        SharedMember,
        SharedWeddingPlansScreen,
        SharingScreen;
import '../../features/shell/shell_api.dart' show WeddingPlanShell;
import '../../features/support/support_api.dart' show SupportScreen;
import '../../features/tasks/tasks_api.dart'
    show CreateTaskScreen, TaskDetailsScreen, TaskTimelineScreen, WeddingTask;
import '../../features/wedding_day/wedding_day_api.dart'
    show WeddingDayModeScreen;
import '../../features/wedding_plans/wedding_plans_api.dart'
    show
        CreateWeddingPlanScreen,
        DashboardSummary,
        MyWeddingPlansScreen,
        PlanAssistantScreen,
        PlanCenterScreen,
        WeddingPlanDashboardScreen;
import '../../features/welcome_gateway/welcome_gateway_api.dart'
    show SmartWelcomeScreen;
import '../config/app_feature_flags.dart';

part 'app_router.entry.dart';
part 'app_router.marketplace.dart';
part 'app_router.provider_portal.dart';
part 'app_router.conversations.dart';
part 'app_router.account.dart';
part 'app_router.plan_shell.dart';
part 'app_router.wedding_plans.dart';

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
  static const inviteAppLinkHost = String.fromEnvironment(
    'AARAST_INVITE_HOST',
    defaultValue: 'aarast.shadowgardn.com',
  );
  static const inviteCustomScheme = String.fromEnvironment(
    'AARAST_INVITE_SCHEME',
    defaultValue: 'aarast',
  );
  static const inviteCustomSchemeHost = 'open';
  static String inviteDecision(String token) =>
      '/invites/${Uri.encodeComponent(token)}';
  static Uri inviteCustomLink(String token) => Uri(
    scheme: inviteCustomScheme,
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

  /// f09 «قارن الملفين»: the two saved providers to compare.
  static String compareProviders(String first, String second) {
    return Uri(
      path: favoriteProviders,
      queryParameters: {'compare': '$first,$second'},
    ).toString();
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

  static String weddingDayMode(String id) {
    return '/wedding-plans/$id/wedding-day';
  }

  static String planCenter(String id) {
    return '/wedding-plans/$id/plan-center';
  }

  static String planAssistant(String id) {
    return '/wedding-plans/$id/assistant';
  }

  static String money(String id) {
    return '/wedding-plans/$id/money';
  }

  static String moneyBudget(String id) {
    return '/wedding-plans/$id/money/budget';
  }

  static String moneyFunding(String id) {
    return '/wedding-plans/$id/money/funding';
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

  static String moneyReceipts(String planId) {
    return '/wedding-plans/$planId/money/receipts';
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

  static String taskDetails(String weddingPlanId, String taskId) {
    return '/wedding-plans/$weddingPlanId/tasks/$taskId';
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

  static String guestInvite(String weddingPlanId, {bool reminder = false}) {
    return Uri(
      path: '/wedding-plans/$weddingPlanId/guests/invite',
      queryParameters: reminder ? {'mode': 'remind'} : null,
    ).toString();
  }

  /// e03 from the phone's contacts, or w28 a pasted list.
  static String guestImport(String weddingPlanId, {bool contacts = false}) {
    return Uri(
      path: '/wedding-plans/$weddingPlanId/guests/import',
      queryParameters: {'from': contacts ? 'contacts' : 'paste'},
    ).toString();
  }

  static String guestDetails(String weddingPlanId, String guestId) {
    return '/wedding-plans/$weddingPlanId/guests/view/$guestId';
  }

  static String guestList(String id) {
    return '/wedding-plans/$id/guests';
  }

  static String guestListAdd(String id) {
    return '/wedding-plans/$id/guests/add';
  }

  /// f04: one service of the wedding, its offers and its booking.
  static String providerRequests(
    String weddingPlanId, {
    String? itemKey,
    String? quoteId,
  }) {
    return Uri(
      path: '/wedding-plans/$weddingPlanId/providers/requests',
      queryParameters: {'item': ?itemKey, 'quote': ?quoteId},
    ).toString();
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
        ..._entryRoutes(flags),
        ..._marketplaceRoutes(),
        ..._providerPortalRoutes(),
        ..._conversationRoutes(),
        ..._accountRoutes(),
        ..._planShellRoutes(),
        ..._weddingPlanRoutes(),
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
    'wedding-day' ||
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
