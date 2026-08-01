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
