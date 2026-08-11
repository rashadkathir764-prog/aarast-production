import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardSummaryProvider request generations', () {
    test('an older dashboard load cannot replace a newer result', () async {
      final first = Completer<DashboardSummary>();
      final second = Completer<DashboardSummary>();
      final api = _ControlledWeddingPlansApi()
        ..responses.addAll([first, second]);
      final provider = DashboardSummaryProvider(weddingPlansApi: api);

      final older = provider.loadDashboard('plan-1');
      final newer = provider.loadDashboard('plan-1');
      second.complete(_summary(title: 'Latest dashboard'));
      await newer;
      first.complete(_summary(title: 'Stale dashboard'));
      await older;

      expect(provider.summary?.title, 'Latest dashboard');
      expect(provider.plan?.title, 'Latest dashboard');
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test(
      'a stale failure cannot finish loading while the latest request is pending',
      () async {
        final first = Completer<DashboardSummary>();
        final second = Completer<DashboardSummary>();
        final api = _ControlledWeddingPlansApi()
          ..responses.addAll([first, second]);
        final provider = DashboardSummaryProvider(weddingPlansApi: api);

        final older = provider.loadDashboard('plan-1');
        final newer = provider.loadDashboard('plan-1');
        first.completeError(const ApiException('stale failure'));
        await older;

        expect(provider.isLoading, isTrue);
        expect(provider.errorMessage, isNull);

        second.complete(_summary(title: 'Latest dashboard'));
        await newer;

        expect(provider.summary?.title, 'Latest dashboard');
        expect(provider.errorMessage, isNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'confirmed task and guest summaries update the live plan pulse',
      () async {
        final response = Completer<DashboardSummary>();
        final api = _ControlledWeddingPlansApi()..responses.add(response);
        final provider = DashboardSummaryProvider(weddingPlansApi: api);
        final load = provider.loadDashboard('plan-1');
        response.complete(
          DashboardSummary.fromJson({
            'planId': 'plan-1',
            'title': 'الخطة',
            'status': 'PLANNING',
            'totalTasks': 5,
            'completedTasks': 1,
            'overdueTasks': 2,
            'todayTasks': 1,
            'guestCount': 10,
            'confirmedGuests': 2,
            'pendingGuests': 7,
            'declinedGuests': 1,
            'incompleteGuestsCount': 3,
          }),
        );
        await load;

        provider.reconcileTaskCounts(
          weddingPlanId: 'plan-1',
          total: 5,
          completed: 2,
          overdue: 1,
          dueToday: 1,
        );
        provider.reconcileGuestCounts(
          weddingPlanId: 'plan-1',
          total: 11,
          confirmed: 4,
          pending: 5,
          declined: 2,
          incomplete: 1,
        );

        expect(provider.summary?.completedTasks, 2);
        expect(provider.summary?.overdueTasks, 1);
        expect(provider.summary?.guestCount, 11);
        expect(provider.summary?.confirmedGuests, 4);
        expect(provider.summary?.incompleteGuestsCount, 1);
      },
    );

    test(
      'a summary from another plan cannot mutate the visible pulse',
      () async {
        final response = Completer<DashboardSummary>();
        final api = _ControlledWeddingPlansApi()..responses.add(response);
        final provider = DashboardSummaryProvider(weddingPlansApi: api);
        final load = provider.loadDashboard('plan-1');
        response.complete(_summary(title: 'Current'));
        await load;

        provider.reconcileTaskCounts(
          weddingPlanId: 'plan-2',
          total: 99,
          completed: 99,
          overdue: 0,
          dueToday: 0,
        );

        expect(provider.summary?.planId, 'plan-1');
        expect(provider.summary?.totalTasks, 0);
      },
    );

    test(
      'local summary owns routed plan chrome without becoming account data',
      () {
        final api = _ControlledWeddingPlansApi();
        final provider = DashboardSummaryProvider(weddingPlansApi: api);
        final local = DashboardSummary.fromJson({
          'dataScope': 'LOCAL',
          'accountBacked': false,
          'planId': 'local-guest-1',
          'title': 'خطة الجهاز',
          'status': 'PLANNING',
          'weddingDate': '2026-09-08T00:00:00.000',
        });

        provider.publishLocalSummary(local);

        expect(provider.summary?.planId, 'local-guest-1');
        expect(provider.summary?.accountBacked, isFalse);
        expect(provider.plan?.title, 'خطة الجهاز');
        expect(provider.isLoading, isFalse);
      },
    );

    test('account-backed summary cannot enter through the local publisher', () {
      final api = _ControlledWeddingPlansApi();
      final provider = DashboardSummaryProvider(weddingPlansApi: api);

      expect(
        () => provider.publishLocalSummary(_summary(title: 'Server plan')),
        throwsArgumentError,
      );
      expect(provider.summary, isNull);
    });
  });
}

class _ControlledWeddingPlansApi extends WeddingPlansApi {
  _ControlledWeddingPlansApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  final List<Completer<DashboardSummary>> responses = [];
  int _requestIndex = 0;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) {
    return responses[_requestIndex++].future;
  }
}

DashboardSummary _summary({required String title}) {
  return DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': title,
    'status': 'PLANNING',
  });
}
