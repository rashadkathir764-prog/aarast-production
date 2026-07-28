import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/media/media_upload_api.dart';
import 'core/network/api_client.dart';
import 'core/offline/local_database.dart';
import 'core/offline/offline_sync_service.dart';
import 'core/session/session_boundary.dart';
import 'core/session/session_scoped_change_notifier.dart';
import 'core/storage/auth_storage.dart';
import 'core/storage/token_vault.dart';
import 'core/storage/sensitive_value_vault.dart';
import 'features/account_contexts/data/account_contexts_api.dart';
import 'features/account_contexts/providers/account_context_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/chat/data/chat_api.dart';
import 'features/chat/data/chat_realtime_client.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/finance/data/finance_api.dart';
import 'features/finance/providers/finance_provider.dart';
import 'features/guests/data/guests_api.dart';
import 'features/guests/providers/guests_provider.dart';
import 'features/home/providers/home_dashboard_provider.dart';
import 'features/marketplace/data/marketplace_api.dart';
import 'features/marketplace/providers/marketplace_provider.dart';
import 'features/notifications/data/notifications_api.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/onboarding/data/guest_onboarding_storage.dart';
import 'features/settings/data/settings_api.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/sharing/data/sharing_api.dart';
import 'features/sharing/providers/sharing_provider.dart';
import 'features/tasks/data/task_timeline_api.dart';
import 'features/tasks/providers/task_timeline_provider.dart';
import 'features/wedding_plans/data/wedding_plans_api.dart';
import 'features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'features/wedding_plans/providers/wedding_plans_provider.dart';

Future<void> main() async {
  ApiConfig.validateForStartup();
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  const sensitiveValueVault = SecureSensitiveValueVault();
  final authStorage = AuthStorage(
    preferences,
    tokenVault: const SecureTokenVault(),
    sensitiveValueVault: sensitiveValueVault,
  );
  await authStorage.initialize();
  final guestOnboardingStorage = GuestOnboardingStorage(
    preferences,
    sensitiveValueVault: sensitiveValueVault,
  );
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  late final LocalDatabase localDatabase;
  try {
    localDatabase = await createLocalDatabase(preferences);
  } on Object {
    runApp(const _SecureOfflineStorageFailureApp());
    return;
  }
  final offlineSyncService = OfflineSyncService(
    database: localDatabase,
    apiClient: apiClient,
  );
  WidgetsBinding.instance.addObserver(offlineSyncService);
  await offlineSyncService.refreshStatus();
  final authRepository = AuthRepository(apiClient, authStorage);
  final accountContextsApi = AccountContextsApi(apiClient);
  apiClient.refreshSession = authRepository.refreshSession;
  final weddingPlansApi = WeddingPlansApi(
    apiClient,
    offline: offlineSyncService,
    authStorage: authStorage,
  );
  final financeApi = FinanceApi(
    apiClient,
    offline: offlineSyncService,
    localPlanContextLoader: (weddingPlanId) async {
      final draft = await guestOnboardingStorage.loadGuestPlan();
      if (draft == null) return null;
      final draftPlanId = draft.guestPlanId?.trim();
      final effectivePlanId = draftPlanId?.isNotEmpty == true
          ? draftPlanId!
          : 'local-guest-plan';
      if (effectivePlanId != weddingPlanId) return null;
      return LocalFinancePlanContext(
        estimatedBudget: draft.estimatedBudget,
        currency: draft.currency,
      );
    },
  );
  final taskTimelineApi = TaskTimelineApi(
    apiClient,
    offline: offlineSyncService,
  );
  final sharingApi = SharingApi(apiClient, offline: offlineSyncService);
  final marketplaceApi = MarketplaceApi(apiClient, offline: offlineSyncService);
  final providerDashboardApi = ProviderDashboardApi(apiClient);
  final mediaUploadApi = MediaUploadApi(apiClient);
  final chatApi = ChatApi(apiClient);
  final chatRealtimeClient = ChatRealtimeClient(authStorage);
  final notificationsApi = NotificationsApi(apiClient);
  final guestsApi = GuestsApi(apiClient, offline: offlineSyncService);
  final settingsApi = SettingsApi(apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: guestOnboardingStorage),
        Provider<ApiClient>.value(value: apiClient),
        Provider<LocalDatabase>.value(value: localDatabase),
        ChangeNotifierProvider<OfflineSyncService>.value(
          value: offlineSyncService,
        ),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<WeddingPlansApi>.value(value: weddingPlansApi),
        Provider<FinanceApi>.value(value: financeApi),
        Provider<TaskTimelineApi>.value(value: taskTimelineApi),
        Provider<SharingApi>.value(value: sharingApi),
        Provider<MarketplaceApi>.value(value: marketplaceApi),
        Provider<ProviderDashboardApi>.value(value: providerDashboardApi),
        Provider<MediaUploadApi>.value(value: mediaUploadApi),
        Provider<ChatApi>.value(value: chatApi),
        Provider<ChatRealtimeClient>.value(value: chatRealtimeClient),
        Provider<NotificationsApi>.value(value: notificationsApi),
        Provider<GuestsApi>.value(value: guestsApi),
        Provider<SettingsApi>.value(value: settingsApi),
        ChangeNotifierProvider(
          create: (_) {
            final controller = AuthController(
              authRepository,
              offlineSyncService: offlineSyncService,
              guestOnboardingStorage: guestOnboardingStorage,
            );
            // A mid-session 401 anywhere forces a clean re-login instead of
            // degrading every screen into misleading errors.
            apiClient.onSessionExpired = () {
              unawaited(controller.handleSessionExpired());
            };
            unawaited(controller.restoreSession());
            return controller;
          },
        ),
      ],
      child: _AarastSessionProviders(
        authStorage: authStorage,
        accountContextsApi: accountContextsApi,
        weddingPlansApi: weddingPlansApi,
        financeApi: financeApi,
        taskTimelineApi: taskTimelineApi,
        sharingApi: sharingApi,
        marketplaceApi: marketplaceApi,
        providerDashboardApi: providerDashboardApi,
        chatApi: chatApi,
        chatRealtimeClient: chatRealtimeClient,
        notificationsApi: notificationsApi,
        guestsApi: guestsApi,
        settingsApi: settingsApi,
      ),
    ),
  );
}

class _SecureOfflineStorageFailureApp extends StatelessWidget {
  const _SecureOfflineStorageFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 52),
                    SizedBox(height: 20),
                    Text(
                      'تعذر فتح التخزين الآمن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'لم يتم حفظ أي بيانات بشكل غير مشفّر. أغلق التطبيق وافتحه مجددًا، وتأكد من تفعيل قفل الشاشة على الجهاز.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AarastSessionProviders extends StatelessWidget {
  const _AarastSessionProviders({
    required this.authStorage,
    required this.accountContextsApi,
    required this.weddingPlansApi,
    required this.financeApi,
    required this.taskTimelineApi,
    required this.sharingApi,
    required this.marketplaceApi,
    required this.providerDashboardApi,
    required this.chatApi,
    required this.chatRealtimeClient,
    required this.notificationsApi,
    required this.guestsApi,
    required this.settingsApi,
  });

  final AuthStorage authStorage;
  final AccountContextsApi accountContextsApi;
  final WeddingPlansApi weddingPlansApi;
  final FinanceApi financeApi;
  final TaskTimelineApi taskTimelineApi;
  final SharingApi sharingApi;
  final MarketplaceApi marketplaceApi;
  final ProviderDashboardApi providerDashboardApi;
  final ChatApi chatApi;
  final ChatRealtimeClient chatRealtimeClient;
  final NotificationsApi notificationsApi;
  final GuestsApi guestsApi;
  final SettingsApi settingsApi;

  @override
  Widget build(BuildContext context) {
    final sessionUserId = context.select<AuthController, String?>(
      (auth) => auth.user?.id,
    );
    final activeWeddingPlanId = context.select<AuthController, String?>(
      (auth) => auth.user?.activeWeddingPlanId,
    );
    return AarastSessionBoundary(
      identity: 'account:${sessionUserId ?? 'guest'}',
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => WeddingPlansProvider(weddingPlansApi),
          ),
          ChangeNotifierProxyProvider<
            WeddingPlansProvider,
            AccountContextController
          >(
            create: (providerContext) => _createAccountContextController(
              providerContext.read<WeddingPlansProvider>(),
              activeWeddingPlanId: activeWeddingPlanId,
              shouldRefresh: sessionUserId != null,
            ),
            update: (_, _, current) =>
                current ??
                (throw StateError(
                  'AccountContextController must be created in-session',
                )),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider(settingsApi)),
          ChangeNotifierProvider(
            create: (_) => ProviderDashboardProvider(providerDashboardApi),
          ),
          ChangeNotifierProvider(
            create: (_) => ChatProvider(
              api: chatApi,
              realtime: chatRealtimeClient,
              authStorage: authStorage,
              sessionUserId: sessionUserId,
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            DashboardSummaryProvider
          >(
            create: (_) => _bindPlanScope(
              DashboardSummaryProvider(weddingPlansApi: weddingPlansApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => DashboardSummaryProvider(weddingPlansApi: weddingPlansApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            HomeDashboardProvider
          >(
            create: (_) => _bindPlanScope(
              HomeDashboardProvider(
                weddingPlansApi: weddingPlansApi,
                sharingApi: sharingApi,
              ),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => HomeDashboardProvider(
                weddingPlansApi: weddingPlansApi,
                sharingApi: sharingApi,
              ),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            FinanceProvider
          >(
            create: (_) => _bindPlanScope(
              FinanceProvider(financeApi, permissionsApi: sharingApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => FinanceProvider(financeApi, permissionsApi: sharingApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            TaskTimelineProvider
          >(
            create: (_) => _bindPlanScope(
              TaskTimelineProvider(taskTimelineApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => TaskTimelineProvider(taskTimelineApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            SharingProvider
          >(
            create: (_) => _bindPlanScope(
              SharingProvider(sharingApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => SharingProvider(sharingApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            NotificationsProvider
          >(
            create: (_) => _bindPlanScope(
              NotificationsProvider(notificationsApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => NotificationsProvider(notificationsApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            GuestsProvider
          >(
            create: (_) =>
                _bindPlanScope(GuestsProvider(guestsApi), _unselectedPlanScope),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => GuestsProvider(guestsApi),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => ProviderMarketplaceProvider(marketplaceApi),
          ),
        ],
        child: const AarastApp(),
      ),
    );
  }

  AccountContextController _createAccountContextController(
    WeddingPlansProvider plans, {
    required String? activeWeddingPlanId,
    required bool shouldRefresh,
  }) {
    final controller = AccountContextController(
      contextsApi: accountContextsApi,
      authStorage: authStorage,
      readActiveWeddingPlanId: () async {
        return (await weddingPlansApi.getActiveWeddingPlan())?.id;
      },
      setActiveWeddingPlan: (planId) async {
        final active = await plans.setActiveWeddingPlan(planId);
        if (active == null) {
          throw const ApiException(
            'تعذر تأكيد الخطة النشطة.',
            isNetworkFailure: true,
          );
        }
      },
    );
    if (shouldRefresh) {
      unawaited(
        controller.refresh(activeWeddingPlanId: activeWeddingPlanId),
      );
    }
    return controller;
  }
}

const _unselectedPlanScope = 'plan:unselected';

String _planScope(AccountContextController accountContexts) {
  final planId = accountContexts.selectedContext?.weddingPlanId;
  return planId == null ? _unselectedPlanScope : 'plan:$planId';
}

T _bindPlanScope<T extends ChangeNotifier>(T provider, Object identity) {
  (provider as SessionScopedState).bindSessionIdentity(identity);
  return provider;
}

T _forPlanScope<T extends ChangeNotifier>(
  T? current,
  Object identity,
  T Function() create,
) {
  if (current != null &&
      (current as SessionScopedState).belongsToSession(identity)) {
    return current;
  }
  return _bindPlanScope(create(), identity);
}
