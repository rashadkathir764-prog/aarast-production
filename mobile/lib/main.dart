import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/media/media_upload_api.dart';
import 'core/network/api_client.dart';
import 'core/offline/local_database.dart';
import 'core/offline/offline_sync_service.dart';
import 'core/storage/auth_storage.dart';
import 'core/storage/token_vault.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/chat/data/chat_api.dart';
import 'features/chat/data/chat_realtime_client.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/debts/data/debt_installment_api.dart';
import 'features/debts/providers/debt_installment_provider.dart';
import 'features/finance/data/budget_expense_api.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(
    preferences,
    tokenVault: const SecureTokenVault(),
  );
  final guestOnboardingStorage = GuestOnboardingStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final localDatabase = await createLocalDatabase(preferences);
  final offlineSyncService = OfflineSyncService(
    database: localDatabase,
    apiClient: apiClient,
  );
  WidgetsBinding.instance.addObserver(offlineSyncService);
  await offlineSyncService.refreshStatus();
  final authRepository = AuthRepository(apiClient, authStorage);
  apiClient.refreshSession = authRepository.refreshSession;
  final weddingPlansApi = WeddingPlansApi(
    apiClient,
    offline: offlineSyncService,
  );
  final budgetExpenseApi = BudgetExpenseApi(
    apiClient,
    offline: offlineSyncService,
  );
  final debtInstallmentApi = DebtInstallmentApi(
    apiClient,
    offline: offlineSyncService,
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
        Provider<BudgetExpenseApi>.value(value: budgetExpenseApi),
        Provider<DebtInstallmentApi>.value(value: debtInstallmentApi),
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
        ChangeNotifierProvider(
          create: (_) => WeddingPlansProvider(weddingPlansApi),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardSummaryProvider(
            weddingPlansApi: weddingPlansApi,
            budgetExpenseApi: budgetExpenseApi,
            debtInstallmentApi: debtInstallmentApi,
            taskTimelineApi: taskTimelineApi,
            sharingApi: sharingApi,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeDashboardProvider(
            weddingPlansApi: weddingPlansApi,
            budgetExpenseApi: budgetExpenseApi,
            debtInstallmentApi: debtInstallmentApi,
            taskTimelineApi: taskTimelineApi,
            sharingApi: sharingApi,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FinanceProvider(budgetExpenseApi),
        ),
        ChangeNotifierProvider(
          create: (_) => DebtInstallmentProvider(debtInstallmentApi),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskTimelineProvider(taskTimelineApi),
        ),
        ChangeNotifierProvider(create: (_) => SharingProvider(sharingApi)),
        ChangeNotifierProvider(
          create: (_) => NotificationsProvider(notificationsApi),
        ),
        ChangeNotifierProvider(create: (_) => GuestsProvider(guestsApi)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(settingsApi)),
        ChangeNotifierProvider(
          create: (_) => ProviderMarketplaceProvider(marketplaceApi),
        ),
        ChangeNotifierProvider(
          create: (_) => ProviderDashboardProvider(providerDashboardApi),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            api: chatApi,
            realtime: chatRealtimeClient,
            authStorage: authStorage,
          ),
        ),
      ],
      child: const AarastApp(),
    ),
  );
}
