import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every long-lived account data provider is session guarded', () {
    const files = [
      'lib/features/wedding_plans/providers/wedding_plans_provider.dart',
      'lib/features/wedding_plans/providers/dashboard_summary_provider.dart',
      'lib/features/home/providers/home_dashboard_provider.dart',
      'lib/features/finance/providers/finance_provider.dart',
      'lib/features/debts/providers/debt_installment_provider.dart',
      'lib/features/tasks/providers/task_timeline_provider.dart',
      'lib/features/sharing/providers/sharing_provider.dart',
      'lib/features/notifications/providers/notifications_provider.dart',
      'lib/features/guests/providers/guests_provider.dart',
      'lib/features/settings/providers/settings_provider.dart',
      'lib/features/marketplace/providers/marketplace_provider.dart',
      'lib/features/chat/providers/chat_provider.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('with SessionScopedNotifier'),
        reason:
            '$path must ignore late completions after its session is disposed',
      );
    }
  });

  test('main scopes account and plan providers at their proper boundaries', () {
    final source = File('lib/main.dart').readAsStringSync();
    final sessionStart = source.indexOf('class _AarastSessionProviders');
    expect(sessionStart, greaterThan(0));

    final rootWiring = source.substring(
      source.indexOf('runApp('),
      sessionStart,
    );
    for (final provider in [
      'WeddingPlansProvider(',
      'DashboardSummaryProvider(',
      'HomeDashboardProvider(',
      'FinanceProvider(',
      'DebtInstallmentProvider(',
      'TaskTimelineProvider(',
      'SharingProvider(',
      'NotificationsProvider(',
      'GuestsProvider(',
      'SettingsProvider(',
      'ProviderMarketplaceProvider(',
      'ProviderDashboardProvider(',
      'ChatProvider(',
    ]) {
      expect(
        rootWiring,
        isNot(contains(provider)),
        reason: '$provider must not live above the account session boundary',
      );
    }

    final sessionWiring = source.substring(sessionStart);
    expect(sessionWiring, contains("identity: 'account:"));
    expect(sessionWiring, contains('sessionUserId: sessionUserId'));
    for (final provider in [
      'DashboardSummaryProvider',
      'HomeDashboardProvider',
      'FinanceProvider',
      'DebtInstallmentProvider',
      'TaskTimelineProvider',
      'SharingProvider',
      'NotificationsProvider',
      'GuestsProvider',
      'ProviderMarketplaceProvider',
    ]) {
      expect(
        sessionWiring,
        matches(
          RegExp(
            'ChangeNotifierProxyProvider<\\s*WeddingPlansProvider,\\s*$provider\\s*>',
          ),
        ),
        reason: '$provider must be replaced when the selected plan changes',
      );
    }
  });
}
