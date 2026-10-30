import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// The home is a projection of the plan, so a write anywhere must reach it: in
// the running app a 250,000 payment left it saying «دفعت 0 ر.ي» (R1).
void main() {
  late StreamController<String> writes;
  late _CountingApi api;
  late DashboardSummaryProvider provider;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() {
    writes = StreamController<String>.broadcast(sync: true);
    api = _CountingApi();
    provider = DashboardSummaryProvider(
      weddingPlansApi: api,
      acceptedWrites: writes.stream,
      writeSettle: const Duration(milliseconds: 5),
    );
  });

  tearDown(() => writes.close());

  test('a write the server accepted reads the home again', () async {
    await provider.loadDashboard('plan-1');
    expect(api.reads, 1);

    writes.add('/api/v1/wedding-costs/cost-1/payments');
    await settle();

    expect(api.reads, 2);
    expect(provider.summary?.title, 'read 2');
    provider.dispose();
  });

  test('a burst of writes reads the home once', () async {
    await provider.loadDashboard('plan-1');

    writes.add('/api/v1/wedding-plans/plan-1/guests');
    writes.add('/api/v1/wedding-plans/plan-1/guests');
    writes.add('/api/v1/wedding-plans/plan-1/tasks');
    await settle();

    expect(api.reads, 2);
    provider.dispose();
  });

  test('a write that does not touch the plan reads nothing', () async {
    await provider.loadDashboard('plan-1');

    for (final path in [
      '/api/v1/auth/login',
      '/api/v1/notifications/note-1/read',
      '/api/v1/push/installations',
      '/api/v1/conversations/chat-1/messages',
      '/api/v1/media/upload-ticket',
    ]) {
      writes.add(path);
    }
    await settle();

    expect(api.reads, 1);
    provider.dispose();
  });

  test('before any home was read, a write reads nothing', () async {
    writes.add('/api/v1/wedding-plans/plan-1/guests');
    await settle();

    expect(api.reads, 0);
    provider.dispose();
  });

  test('a provider that left stops listening', () async {
    await provider.loadDashboard('plan-1');
    writes.add('/api/v1/wedding-plans/plan-1/guests');
    provider.dispose();
    await settle();

    expect(api.reads, 1);
  });

  test('a failed read keeps the home it had', () async {
    await provider.loadDashboard('plan-1');
    api.failNext = true;

    writes.add('/api/v1/wedding-plans/plan-1/guests');
    await settle();

    expect(provider.summary?.title, 'read 1');
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });
}

class _CountingApi extends WeddingPlansApi {
  _CountingApi() : super(ApiClient(tokenProvider: () async => null));

  int reads = 0;
  bool failNext = false;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async {
    reads += 1;
    if (failNext) {
      failNext = false;
      throw const ApiException('no connection');
    }
    return DashboardSummary.fromJson({
      'planId': planId,
      'title': 'read $reads',
      'status': 'PLANNING',
    });
  }
}
