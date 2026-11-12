import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  testWidgets(
    'owner dashboard reloads pending invites after returning from sharing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final auth = _AuthenticatedAuthController(
        AuthRepository(apiClient, storage),
      );
      final ownerContext = accountContext(
        role: AccountContextRole.owner,
        planId: _planId,
      );
      final contexts = AccountContextController(
        contextsApi: _ContextsGateway(ownerContext),
        authStorage: storage,
        setActiveWeddingPlan: (_) async {},
      );
      await contexts.refresh();
      expect(await contexts.select(ownerContext.contextKey), isTrue);

      final dashboard = _RecordingDashboardProvider(
        WeddingPlansApi(apiClient),
        _ownerSummary(),
      );
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) =>
                const WeddingPlanDashboardScreen(weddingPlanId: _planId),
          ),
          GoRoute(
            path: '/wedding-plans/:id/sharing',
            builder: (context, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('close-sharing'),
                  onPressed: context.pop,
                  child: const Text('إغلاق المشاركة'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/wedding-plans/:id/notifications',
            builder: (context, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('close-notifications'),
                  onPressed: context.pop,
                  child: const Text('إغلاق التنبيهات'),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(() {
        router.dispose();
        dashboard.dispose();
        contexts.dispose();
        auth.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<AccountContextController>.value(
              value: contexts,
            ),
            ChangeNotifierProvider<DashboardSummaryProvider>.value(
              value: dashboard,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dashboard.loadCalls, 1);
      final sharingAction = find.byKey(
        const ValueKey('aarast-dashboard-sharing'),
      );
      expect(sharingAction, findsOneWidget);
      await tester.ensureVisible(sharingAction);
      await tester.pumpAndSettle();
      await tester.tap(sharingAction);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('close-sharing')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-sharing')));
      await tester.pumpAndSettle();

      expect(dashboard.loadCalls, 2);

      // RA-MO-149: the bell's dot is the summary's unread count, and reading
      // the notices is not a write that rereads the summary: back from the
      // list the dot stayed red until the next pull to refresh.
      final bell = find.byTooltip('التنبيهات');
      await tester.ensureVisible(bell);
      await tester.pumpAndSettle();
      await tester.tap(bell);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('close-notifications')), findsOneWidget);
      await tester.tap(find.byKey(const Key('close-notifications')));
      await tester.pumpAndSettle();

      expect(dashboard.loadCalls, 3);
      expect(tester.takeException(), isNull);
    },
  );
}

const _planId = 'owner-plan';

DashboardSummary _ownerSummary() {
  return DashboardSummary.fromJson({
    'planId': _planId,
    'title': 'خطة المالك',
    'status': 'PLANNING',
    'budgetTotal': '100000',
    'progressPercentage': 0,
    'totalTasks': 1,
    'completedTasks': 0,
    'overdueTasks': 0,
    'todayTasks': 0,
    'guestCount': 1,
    // A running plan: its first steps are done (b01).
    'venueSecured': true,
    'confirmedGuests': 0,
    'providerCount': 0,
    'quoteRequestsCount': 0,
    'participantCount': 1,
    'pendingInvites': 1,
    'unreadNotificationsCount': 0,
    'nextBestActions': const [],
    'permissions': {
      'isOwner': true,
      'role': 'OWNER',
      'canViewMoney': true,
      'canManageTasks': true,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManageMembers': true,
      'canManageMoney': true,
      'canManagePlan': true,
    },
  });
}

class _RecordingDashboardProvider extends DashboardSummaryProvider {
  _RecordingDashboardProvider(
    WeddingPlansApi weddingPlansApi,
    this.currentSummary,
  ) : super(weddingPlansApi: weddingPlansApi);

  final DashboardSummary currentSummary;
  int loadCalls = 0;

  @override
  DashboardSummary get summary => currentSummary;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {
    loadCalls += 1;
  }
}

class _AuthenticatedAuthController extends AuthController {
  _AuthenticatedAuthController(super.repository);

  static const _user = SafeUser(
    id: 'owner-user',
    name: 'صاحب الخطة',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  SafeUser? get user => _user;
}

class _ContextsGateway implements AccountContextsGateway {
  const _ContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
