import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every long-lived account data provider is session guarded', () {
    const files = [
      'lib/features/wedding_plans/providers/wedding_plans_provider.dart',
      'lib/features/wedding_plans/providers/dashboard_summary_provider.dart',
      'lib/features/home/providers/home_dashboard_provider.dart',
      'lib/features/finance/providers/finance_provider.dart',
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
      'AccountContextController(',
      'WeddingPlansProvider(',
      'DashboardSummaryProvider(',
      'HomeDashboardProvider(',
      'FinanceProvider(',
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
    expect(
      sessionWiring,
      matches(
        RegExp(
          'ChangeNotifierProxyProvider<\\s*WeddingPlansProvider,\\s*AccountContextController\\s*>',
        ),
      ),
      reason:
          'account contexts must be recreated inside the authenticated account boundary',
    );
    expect(
      sessionWiring,
      isNot(contains('activeWeddingPlanId:')),
      reason:
          'legacy active plan metadata must never select an account context',
    );
    for (final provider in [
      'DashboardSummaryProvider',
      'HomeDashboardProvider',
      'FinanceProvider',
      'TaskTimelineProvider',
      'SharingProvider',
      'NotificationsProvider',
      'GuestsProvider',
      'ProviderMarketplaceProvider',
      'ProviderDashboardProvider',
      'ChatProvider',
    ]) {
      expect(
        sessionWiring,
        matches(
          RegExp(
            'ChangeNotifierProxyProvider<\\s*AccountContextController,\\s*$provider\\s*>',
          ),
        ),
        reason:
            '$provider must be replaced from the selected account context, not legacy plan state',
      );
    }

    expect(
      sessionWiring,
      contains('controller.refresh(allowInitialSingleContext: true)'),
      reason:
          'only the first confirmed single-context login may enter directly',
    );
  });
}
