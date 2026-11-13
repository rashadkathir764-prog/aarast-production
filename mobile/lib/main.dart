import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/config/observability_config.dart';
import 'core/diagnostics/app_logger.dart';
import 'core/diagnostics/diagnostic_report_sender.dart';
import 'core/diagnostics/sentry_log_sink.dart';
import 'core/forms/aarast_form_draft_store.dart';
import 'core/media/media_upload_api.dart';
import 'core/network/api_client.dart';
import 'core/network/server_reachability.dart';
import 'core/offline/local_database.dart';
import 'core/offline/offline_sync_service.dart';
import 'core/offline/pending_plan_cleanup.dart';
import 'core/offline/side_outboxes.dart';
import 'core/preferences/device_preferences.dart';
import 'core/push/push_messaging_gateway.dart';
import 'core/push/push_notifications_controller.dart';
import 'core/push/push_registration_api.dart';
import 'core/security/app_lock_controller.dart';
import 'core/session/session_boundary.dart';
import 'core/session/session_scoped_change_notifier.dart';
import 'core/session/session_teardown_coordinator.dart';
import 'core/storage/auth_storage.dart';
import 'core/storage/token_vault.dart';
import 'core/storage/sensitive_value_vault.dart';
import 'features/account_contexts/account_contexts_api.dart'
    show AccountContextsApi, AccountContextController;
import 'features/auth/auth_api.dart' show AuthController, AuthRepository;
import 'features/catalogs/catalogs_api.dart'
    show ReferenceCatalogApi, ReferenceCatalogProvider;
import 'features/chat/chat_api.dart'
    show ChatApi, ChatOutbox, ChatProvider, ChatRealtimeClient;
import 'features/finance/finance_api.dart'
    show
        FinanceApi,
        FinanceProvider,
        FundingApi,
        FundingProvider,
        LocalFinancePlanContext;
import 'features/guests/guests_api.dart' show GuestsApi, GuestsProvider;
import 'features/marketplace/marketplace_api.dart'
    show MarketplaceApi, ProviderDashboardApi, ProviderMarketplaceProvider;
import 'features/notifications/notifications_api.dart'
    show NotificationsApi, NotificationsProvider;
import 'features/onboarding/onboarding_api.dart'
    show
        GuestOnboardingStorage,
        YemenAdministrativeApi,
        YemenAdministrativeProvider;
import 'features/provider_portal/provider_portal_api.dart'
    show ProviderDashboardProvider, ProviderOfferQueue;
import 'features/settings/settings_api.dart' show SettingsApi, SettingsProvider;
import 'features/sharing/sharing_api.dart'
    show
        ContributionHistoryProvider,
        PlanLeaveCoordinator,
        SharingApi,
        SharingProvider;
import 'features/tasks/tasks_api.dart'
    show TaskTimelineApi, TaskTimelineProvider;
import 'features/wedding_day/wedding_day_api.dart'
    show PlanEventsApi, PlanEventsProvider;
import 'features/wedding_plans/wedding_plans_api.dart'
    show
        DashboardSummaryProvider,
        PlanReadViewProvider,
        WeddingPlansApi,
        WeddingPlansProvider;
import 'core/experience_v3/aarast_journey.dart';
import 'core/experience_v3/aarast_v3_foundations.dart';

Future<void> main() async {
  const observability = ObservabilityConfig.fromEnvironment();
  final bootstrapRedactor = LogRedactor(
    installationSalt: 'aarast-observability-bootstrap-v1',
  );
  final bootstrapSentrySink = SentryAppLogSink(redactor: bootstrapRedactor);

  Future<void> appRunner() => _bootstrapApplication(observability);
  if (!observability.isEnabled) {
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) => observability.applyTo(
      options,
      beforeSend: bootstrapSentrySink.beforeSend,
      beforeBreadcrumb: bootstrapSentrySink.beforeBreadcrumb,
    ),
    appRunner: appRunner,
  );
}

Future<void> _bootstrapApplication(ObservabilityConfig observability) async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final installationSalt = await _readOrCreateObservabilitySalt(preferences);
  final redactor = LogRedactor(installationSalt: installationSalt);
  final memoryLogSink = MemoryRingBufferSink();
  final logger = AppLogger(
    redactor: redactor,
    sinks: [
      DebugConsoleAppLogSink(),
      memoryLogSink,
      if (observability.isEnabled) SentryAppLogSink(redactor: redactor),
    ],
  );
  AppLogger.installGlobal(logger);
  logger.startSessionCorrelation();
  final DiagnosticReportService diagnosticReportService =
      observability.isEnabled
      ? DiagnosticReportSender(
          ringBuffer: memoryLogSink,
          redactor: redactor,
          transport: DirectSentryDiagnosticReportTransport(
            dsn: observability.dsn,
            environment: observability.environment,
            release: observability.release,
          ),
        )
      : const UnavailableDiagnosticReportService();
  logger.log(
    level: AppLogLevel.info,
    category: AppLogCategory.lifecycle,
    name: 'application_start',
    attributes: {'environment': observability.environment},
  );
  logger.log(
    level: AppLogLevel.info,
    category: AppLogCategory.lifecycle,
    name: 'observability_initialized',
    attributes: {
      'sentryEnabled': observability.isEnabled,
      'tracesSampleRate': observability.tracesSampleRate,
    },
  );

  ApiConfig.validateForStartup();
  const sensitiveValueVault = SecureSensitiveValueVault();
  final authStorage = AuthStorage(
    preferences,
    tokenVault: const SecureTokenVault(),
    sensitiveValueVault: sensitiveValueVault,
  );
  logger.log(
    level: AppLogLevel.info,
    category: AppLogCategory.session,
    name: 'session_storage_initialization_started',
  );
  await authStorage.initialize();
  logger.log(
    level: AppLogLevel.info,
    category: AppLogCategory.session,
    name: 'session_storage_initialization_completed',
  );
  final guestOnboardingStorage = GuestOnboardingStorage(
    preferences,
    sensitiveValueVault: sensitiveValueVault,
  );
  // D75: whose plan is on this phone, for the colour and words of the
  // screens before the account.
  unawaited(guestOnboardingStorage.loadDraft());
  final formDraftStore = AarastFormDraftStore(
    vault: sensitiveValueVault,
    authStorage: authStorage,
  );
  // D84: one measured answer to «هل الخادم يرد؟», read by the sync
  // service, the banner and «فحص الاتصال».
  final serverReachability = ServerReachability();
  final apiClient = ApiClient(
    tokenProvider: authStorage.readAccessToken,
    reachability: serverReachability,
  );
  final devicePreferences = DevicePreferences(preferences);
  late final LocalDatabase localDatabase;
  try {
    localDatabase = await createLocalDatabase(preferences);
    logger.log(
      level: AppLogLevel.info,
      category: AppLogCategory.database,
      name: 'offline_database_opened',
    );
  } on Object catch (error, stackTrace) {
    logger.log(
      level: AppLogLevel.fatal,
      category: AppLogCategory.database,
      name: 'offline_database_open_failed',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(const _SecureOfflineStorageFailureApp());
    return;
  }
  final pendingPlanCleanupStore = PendingPlanCleanupStore(preferences);
  final offlineSyncService = OfflineSyncService(
    database: localDatabase,
    apiClient: apiClient,
    pendingPlanCleanupStore: pendingPlanCleanupStore,
    reachability: serverReachability,
  );
  WidgetsBinding.instance.addObserver(offlineSyncService);
  await offlineSyncService.refreshStatus();
  final authRepository = AuthRepository(apiClient, authStorage);
  final pushNotificationsController = PushNotificationsController(
    preferences: preferences,
    gateway: FirebasePushMessagingGateway(),
    registrationApi: PushRegistrationApi(apiClient),
  );
  await pushNotificationsController.initialize();
  // RA-MO-101: «الخروج» names these waiting writes with the rest.
  SideOutboxes.register(() => ChatOutbox.countAll(preferences));
  SideOutboxes.register(() => ProviderOfferQueue.countAll(preferences));
  final sessionTeardownCoordinator = SessionTeardownCoordinator(
    auth: authRepository,
    push: pushNotificationsController,
    clearLocalAccountData: () async {
      await offlineSyncService.clearLocalData();
      await formDraftStore.clearAll();
      // RA-MO-101: the chat's and the offers' waiting writes go with the
      // rest of the account's data; they stayed and went at the next sign-in.
      await ChatOutbox.clearAll(preferences);
      await ProviderOfferQueue.clearAll(preferences);
    },
    clearLocalAccountDataKeepingUnsent: () async {
      await offlineSyncService.clearLocalData(keepUnsentChanges: true);
      await formDraftStore.clearAll();
    },
    clearGuestDraft: guestOnboardingStorage.clearDraft,
    clearDeletedAccountState: (userId) async {
      await pendingPlanCleanupStore.removeForUser(userId);
    },
  );
  final accountContextsApi = AccountContextsApi(
    apiClient,
    offline: offlineSyncService,
  );
  apiClient.refreshSession = authRepository.refreshSession;
  final weddingPlansApi = WeddingPlansApi(
    apiClient,
    offline: offlineSyncService,
    authStorage: authStorage,
  );
  final fundingApi = FundingApi(apiClient, offline: offlineSyncService);
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
        persona: draft.persona?.name.toUpperCase(),
        mahrTotal: draft.mahr?.total,
        mahrSettled: draft.mahr?.settled,
        mahrDueDate: draft.mahr?.remainingDueDate,
      );
    },
  );
  final taskTimelineApi = TaskTimelineApi(
    apiClient,
    offline: offlineSyncService,
  );
  final sharingApi = SharingApi(apiClient, offline: offlineSyncService);
  final planLeaveCoordinator = PlanLeaveCoordinator(
    sharingApi: sharingApi,
    offlineSync: offlineSyncService,
    store: pendingPlanCleanupStore,
  );
  final marketplaceApi = MarketplaceApi(apiClient, offline: offlineSyncService);
  final yemenAdministrativeApi = YemenAdministrativeApi(
    apiClient,
    offline: offlineSyncService,
  );
  final referenceCatalogApi = ReferenceCatalogApi(
    apiClient,
    offlineSyncService,
  );
  final providerDashboardApi = ProviderDashboardApi(
    apiClient,
    offline: offlineSyncService,
  );
  final mediaUploadApi = MediaUploadApi(apiClient);
  final chatApi = ChatApi(apiClient, offline: offlineSyncService);
  final chatRealtimeClient = ChatRealtimeClient(authStorage);
  final notificationsApi = NotificationsApi(
    apiClient,
    offline: offlineSyncService,
  );
  final guestsApi = GuestsApi(apiClient, offline: offlineSyncService);
  final settingsApi = SettingsApi(apiClient, offline: offlineSyncService);

  logger.log(
    level: AppLogLevel.info,
    category: AppLogCategory.lifecycle,
    name: 'application_dependencies_ready',
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AppLogger>.value(value: logger),
        Provider<MemoryRingBufferSink>.value(value: memoryLogSink),
        ChangeNotifierProvider<ServerReachability>.value(
          value: serverReachability,
        ),
        Provider<DiagnosticReportService>.value(value: diagnosticReportService),
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AarastFormDraftStore>.value(value: formDraftStore),
        Provider<GuestOnboardingStorage>.value(value: guestOnboardingStorage),
        Provider<ApiClient>.value(value: apiClient),
        Provider<LocalDatabase>.value(value: localDatabase),
        ChangeNotifierProvider<OfflineSyncService>.value(
          value: offlineSyncService,
        ),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<PushNotificationsController>.value(
          value: pushNotificationsController,
        ),
        Provider<WeddingPlansApi>.value(value: weddingPlansApi),
        Provider<FinanceApi>.value(value: financeApi),
        ChangeNotifierProvider<DevicePreferences>.value(
          value: devicePreferences,
        ),
        Provider<TaskTimelineApi>.value(value: taskTimelineApi),
        Provider<SharingApi>.value(value: sharingApi),
        Provider<PlanLeaveCoordinator>.value(value: planLeaveCoordinator),
        Provider<MarketplaceApi>.value(value: marketplaceApi),
        ChangeNotifierProvider(
          create: (_) =>
              YemenAdministrativeProvider(yemenAdministrativeApi)
                ..loadGovernorates(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReferenceCatalogProvider(referenceCatalogApi)..load(),
        ),
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
              sessionTeardownCoordinator: sessionTeardownCoordinator,
            );
            // A mid-session 401 anywhere forces a clean re-login instead of
            // degrading every screen into misleading errors.
            apiClient.onSessionExpired = () {
              unawaited(controller.handleSessionExpired());
            };
            // D63: another phone asked to delete the account; w06 shows.
            apiClient.onAccountDeletionPending = () {
              unawaited(controller.handleAccountDeletionPending());
            };
            unawaited(controller.restoreSession());
            return controller;
          },
        ),
      ],
      child: _AarastSessionProviders(
        apiClient: apiClient,
        authStorage: authStorage,
        offlineSyncService: offlineSyncService,
        accountContextsApi: accountContextsApi,
        weddingPlansApi: weddingPlansApi,
        financeApi: financeApi,
        fundingApi: fundingApi,
        taskTimelineApi: taskTimelineApi,
        sharingApi: sharingApi,
        planLeaveCoordinator: planLeaveCoordinator,
        marketplaceApi: marketplaceApi,
        providerDashboardApi: providerDashboardApi,
        providerOfferQueue: ProviderOfferQueue(preferences),
        chatOutbox: ChatOutbox(preferences),
        chatApi: chatApi,
        chatRealtimeClient: chatRealtimeClient,
        notificationsApi: notificationsApi,
        guestsApi: guestsApi,
        settingsApi: settingsApi,
      ),
    ),
  );
}

const _observabilityInstallationSaltKey =
    'aarast.observability.installation_salt.v1';

Future<String> _readOrCreateObservabilitySalt(
  SharedPreferences preferences,
) async {
  final existing = preferences
      .getString(_observabilityInstallationSaltKey)
      ?.trim();
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final generated = base64UrlEncode(bytes);
  await preferences.setString(_observabilityInstallationSaltKey, generated);
  return generated;
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
                padding: EdgeInsets.all(AarastV3Space.x8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 52),
                    SizedBox(height: AarastV3Space.x5),
                    Text(
                      'ما قدرنا نفتح التطبيق بأمان',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: JourneyType.sheetTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AarastV3Space.x3),
                    Text(
                      'ما حفظنا أي شي بدون حماية. سكّر التطبيق وافتحه مرة ثانية، وتأكد إن قفل الشاشة شغّال في الجوال.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: JourneyType.bodyLarge,
                        height: 1.6,
                      ),
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
    required this.apiClient,
    required this.authStorage,
    required this.offlineSyncService,
    required this.accountContextsApi,
    required this.weddingPlansApi,
    required this.financeApi,
    required this.fundingApi,
    required this.taskTimelineApi,
    required this.sharingApi,
    required this.planLeaveCoordinator,
    required this.marketplaceApi,
    required this.providerDashboardApi,
    required this.providerOfferQueue,
    required this.chatOutbox,
    required this.chatApi,
    required this.chatRealtimeClient,
    required this.notificationsApi,
    required this.guestsApi,
    required this.settingsApi,
  });

  final ApiClient apiClient;
  final AuthStorage authStorage;
  final OfflineSyncService offlineSyncService;
  final AccountContextsApi accountContextsApi;
  final WeddingPlansApi weddingPlansApi;
  final FinanceApi financeApi;
  final FundingApi fundingApi;
  final TaskTimelineApi taskTimelineApi;
  final SharingApi sharingApi;
  final PlanLeaveCoordinator planLeaveCoordinator;
  final MarketplaceApi marketplaceApi;
  final ProviderDashboardApi providerDashboardApi;

  /// The provider's offers sent with no network (p43).
  final ProviderOfferQueue providerOfferQueue;

  /// G38: chat messages written with no network.
  final ChatOutbox chatOutbox;
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
              shouldRefresh: sessionUserId != null,
              userId: sessionUserId,
            ),
            update: (_, _, current) =>
                current ??
                (throw StateError(
                  'AccountContextController must be created in-session',
                )),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider(settingsApi)),
          // V1 checklist 4.15: the account's optional app lock code.
          ChangeNotifierProvider(
            create: (_) => AppLockController(
              vault: const SecureSensitiveValueVault(),
              userId: sessionUserId,
            )..load(),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            ProviderDashboardProvider
          >(
            create: (_) => _bindPlanScope(
              ProviderDashboardProvider(
                providerDashboardApi,
                offerQueue: providerOfferQueue,
              ),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => ProviderDashboardProvider(
                providerDashboardApi,
                offerQueue: providerOfferQueue,
              ),
            ),
          ),
          ChangeNotifierProxyProvider<AccountContextController, ChatProvider>(
            create: (_) => _bindPlanScope(
              ChatProvider(
                api: chatApi,
                realtime: chatRealtimeClient,
                authStorage: authStorage,
                sessionUserId: sessionUserId,
                outbox: chatOutbox,
              ),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => ChatProvider(
                api: chatApi,
                realtime: chatRealtimeClient,
                authStorage: authStorage,
                sessionUserId: sessionUserId,
                outbox: chatOutbox,
              ),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            DashboardSummaryProvider
          >(
            create: (_) => _bindPlanScope(
              DashboardSummaryProvider(
                weddingPlansApi: weddingPlansApi,
                acceptedWrites: apiClient.acceptedWrites,
              ),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => DashboardSummaryProvider(
                weddingPlansApi: weddingPlansApi,
                acceptedWrites: apiClient.acceptedWrites,
              ),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            PlanReadViewProvider
          >(
            create: (_) => _bindPlanScope(
              PlanReadViewProvider(weddingPlansApi: weddingPlansApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => PlanReadViewProvider(weddingPlansApi: weddingPlansApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            PlanEventsProvider
          >(
            create: (context) => _bindPlanScope(
              PlanEventsProvider(
                api: PlanEventsApi(
                  context.read<ApiClient>(),
                  offline: offlineSyncService,
                ),
              ),
              _unselectedPlanScope,
            ),
            update: (context, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => PlanEventsProvider(
                api: PlanEventsApi(
                  context.read<ApiClient>(),
                  offline: offlineSyncService,
                ),
              ),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            FinanceProvider
          >(
            create: (context) => _bindPlanScope(
              FinanceProvider(
                financeApi,
                permissionsApi: sharingApi,
                preferences: context.read<DevicePreferences>(),
              ),
              _unselectedPlanScope,
            ),
            update: (context, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => FinanceProvider(
                financeApi,
                permissionsApi: sharingApi,
                preferences: context.read<DevicePreferences>(),
              ),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            FundingProvider
          >(
            create: (_) => _bindPlanScope(
              FundingProvider(fundingApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => FundingProvider(fundingApi),
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
            ContributionHistoryProvider
          >(
            create: (_) => _bindPlanScope(
              ContributionHistoryProvider(sharingApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => ContributionHistoryProvider(sharingApi),
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
          ChangeNotifierProxyProvider<AccountContextController, GuestsProvider>(
            create: (_) =>
                _bindPlanScope(GuestsProvider(guestsApi), _unselectedPlanScope),
            update: (_, accountContexts, current) => _forPlanScope(
              current,
              _planScope(accountContexts),
              () => GuestsProvider(guestsApi),
            ),
          ),
          ChangeNotifierProxyProvider<
            AccountContextController,
            ProviderMarketplaceProvider
          >(
            create: (_) => _bindPlanScope(
              ProviderMarketplaceProvider(marketplaceApi),
              _unselectedPlanScope,
            ),
            update: (_, accountContexts, current) {
              final marketplace = _forPlanScope(
                current,
                _planScope(accountContexts),
                () => ProviderMarketplaceProvider(
                  marketplaceApi,
                  catalogAudience:
                      accountContexts.selectedContext?.persona?.name,
                ),
              );
              marketplace.configureCatalogAudience(
                accountContexts.selectedContext?.persona?.name,
                notify: false,
              );
              return marketplace;
            },
          ),
        ],
        child: const AarastApp(),
      ),
    );
  }

  AccountContextController _createAccountContextController(
    WeddingPlansProvider plans, {
    required bool shouldRefresh,
    required String? userId,
  }) {
    final controller = AccountContextController(
      contextsApi: accountContextsApi,
      authStorage: authStorage,
      userId: userId,
      readActiveWeddingPlanId: () async {
        return (await weddingPlansApi.getActiveWeddingPlan())?.id;
      },
      setActiveWeddingPlan: (planId) async {
        final active = await plans.setActiveWeddingPlan(planId);
        if (active == null) {
          throw const ApiException(
            'ما قدرنا نتأكد من الخطة المفتوحة.',
            isNetworkFailure: true,
          );
        }
      },
      resetContextState: (previousContext, nextContext) async {
        apiClient.bindContextIdentity(nextContext?.contextKey);
        plans.clearContextState();
        // D86: the previous plan's copy and queued writes stay on the
        // phone; only leaving a plan removes them.
        final previousPlanId = previousContext?.weddingPlanId;
        if (previousPlanId != null) {
          await offlineSyncService.switchPlanContext(previousPlanId);
        }
      },
      beforeRefresh: userId == null
          ? null
          : () => planLeaveCoordinator.preparePendingForUser(userId),
      afterRefresh: userId == null
          ? null
          : () => planLeaveCoordinator.completeAfterContextsRefreshForUser(
              userId,
            ),
      // RA-MO-275: taken off a plan, its copy and stuck changes go.
      forgetRemovedPlan: (planId) async {
        final unsent = await offlineSyncService.unsentCountForPlan(planId);
        await offlineSyncService.clearPlanContext(planId);
        return unsent;
      },
    );
    if (shouldRefresh) {
      unawaited(controller.refresh(allowInitialSingleContext: true));
    }
    return controller;
  }
}

const _unselectedPlanScope = 'context:none';

String _planScope(AccountContextController accountContexts) {
  final selected = accountContexts.selectedContext;
  final contextKey = selected?.contextKey;
  if (contextKey == null) return _unselectedPlanScope;
  // D112 (Q-21): a plan put in the memories keeps its key and loses every
  // write right. Its pages start afresh as a memory, so nothing read with
  // the rights it had a moment ago (the money's «تقدر تسجّل») stays shown.
  return selected!.isOwnerMemory
      ? 'context:$contextKey:memory'
      : 'context:$contextKey';
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
