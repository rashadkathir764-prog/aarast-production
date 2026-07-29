import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeddingPlansProvider request generations', () {
    test('an older plan load cannot replace a newer selected plan', () async {
      final first = Completer<WeddingPlan>();
      final second = Completer<WeddingPlan>();
      final api = _ControlledWeddingPlansApi()
        ..onGetPlan = (id) => id == 'plan-1' ? first.future : second.future;
      final provider = WeddingPlansProvider(api);

      final older = provider.loadWeddingPlan('plan-1');
      final newer = provider.loadWeddingPlan('plan-2');
      second.complete(_plan('plan-2'));
      await newer;
      first.complete(_plan('plan-1'));
      await older;

      expect(provider.selectedPlan?.id, 'plan-2');
      expect(provider.errorMessage, isNull);
    });

    test(
      'an older set-active result cannot replace a newer active plan',
      () async {
        final first = Completer<ActiveWeddingPlan>();
        final second = Completer<ActiveWeddingPlan>();
        final api = _ControlledWeddingPlansApi()
          ..onSetActive = (id) => id == 'plan-1' ? first.future : second.future;
        final provider = WeddingPlansProvider(api);

        final older = provider.setActiveWeddingPlan('plan-1');
        final newer = provider.setActiveWeddingPlan('plan-2');
        second.complete(_activePlan('plan-2'));
        expect((await newer)?.id, 'plan-2');
        first.complete(_activePlan('plan-1'));
        expect(await older, isNull);

        expect(provider.activePlan?.id, 'plan-2');
        expect(provider.selectedPlan?.id, 'plan-2');
      },
    );

    test(
      'a stale load-active response cannot undo a newer explicit selection',
      () async {
        final pendingActive = Completer<ActiveWeddingPlan?>();
        final api = _ControlledWeddingPlansApi();
        api.onGetActive = () => pendingActive.future;
        api.onSetActive = (id) async => _activePlan(id);
        final provider = WeddingPlansProvider(api);

        final staleRestore = provider.loadActiveWeddingPlan();
        final selected = await provider.setActiveWeddingPlan('plan-2');
        expect(selected?.id, 'plan-2');
        pendingActive.complete(_activePlan('plan-1'));
        await staleRestore;

        expect(provider.activePlan?.id, 'plan-2');
        expect(provider.selectedPlan?.id, 'plan-2');
      },
    );
  });
}

class _ControlledWeddingPlansApi extends WeddingPlansApi {
  _ControlledWeddingPlansApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  Future<WeddingPlan> Function(String id) onGetPlan = (id) async => _plan(id);
  Future<ActiveWeddingPlan?> Function() onGetActive = () async => null;
  Future<ActiveWeddingPlan> Function(String id) onSetActive = (id) async =>
      _activePlan(id);

  @override
  Future<WeddingPlan> getWeddingPlan(String id) => onGetPlan(id);

  @override
  Future<ActiveWeddingPlan?> getActiveWeddingPlan() => onGetActive();

  @override
  Future<ActiveWeddingPlan> setActiveWeddingPlan(String id) => onSetActive(id);
}

WeddingPlan _plan(String id) {
  final now = DateTime.utc(2026, 7, 28);
  return WeddingPlan(
    id: id,
    ownerUserId: 'user-1',
    title: 'Plan $id',
    currency: 'YER',
    status: 'PLANNING',
    createdAt: now,
    updatedAt: now,
  );
}

ActiveWeddingPlan _activePlan(String id) {
  return ActiveWeddingPlan.fromWeddingPlan(_plan(id));
}
