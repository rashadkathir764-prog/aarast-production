import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountContextController desired-state reconciliation', () {
    test(
      'a refresh requested during pending set-active restores its newer plan intent',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final pendingPlan2 = Completer<void>();
        final harness = await _Harness.create(
          contexts: [plan1, plan2],
          serverActivePlanId: plan1.weddingPlanId,
          persistedContextKey: plan1.contextKey,
          onSetActive: (planId) {
            if (planId == plan2.weddingPlanId) return pendingPlan2.future;
            return Future<void>.value();
          },
        );
        await harness.controller.refresh();

        final selection = harness.controller.select(plan2.contextKey);
        await _flush();
        expect(harness.serverActivePlanId, plan2.weddingPlanId);

        final refresh = harness.controller.refresh();
        pendingPlan2.complete();
        expect(await selection, isFalse);
        await refresh;

        expect(harness.controller.selectedContext, plan1);
        expect(harness.storage.readAccountContextKey(), plan1.contextKey);
        expect(harness.storage.readActivePlanId(), plan1.weddingPlanId);
        expect(harness.serverActivePlanId, plan1.weddingPlanId);
        expect(harness.setActiveCalls, [
          plan2.weddingPlanId,
          plan1.weddingPlanId,
        ]);
      },
    );

    test(
      'provider selection superseding pending set-active clears local plan state',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final provider = accountContext(role: AccountContextRole.provider);
        final pendingPlan2 = Completer<void>();
        final harness = await _Harness.create(
          contexts: [plan1, plan2, provider],
          serverActivePlanId: plan1.weddingPlanId,
          persistedContextKey: plan1.contextKey,
          onSetActive: (planId) {
            if (planId == plan2.weddingPlanId) return pendingPlan2.future;
            return Future<void>.value();
          },
        );
        await harness.controller.refresh();

        final stalePlanSelection = harness.controller.select(plan2.contextKey);
        await _flush();
        final providerSelection = harness.controller.select(
          provider.contextKey,
        );
        pendingPlan2.complete();

        expect(await stalePlanSelection, isFalse);
        expect(await providerSelection, isTrue);
        expect(harness.controller.selectedContext, provider);
        expect(harness.storage.readAccountContextKey(), provider.contextKey);
        expect(harness.storage.readActivePlanId(), isNull);
        expect(harness.serverActivePlanId, plan2.weddingPlanId);
        expect(harness.setActiveCalls, [plan2.weddingPlanId]);
      },
    );

    test('newer select wins over an older pending refresh', () async {
      final plan1 = accountContext(role: AccountContextRole.owner);
      final plan2 = accountContext(
        role: AccountContextRole.contributor,
        planId: 'plan-2',
      );
      final pendingList = Completer<List<AccountContext>>();
      final harness = await _Harness.create(
        contexts: [plan1, plan2],
        serverActivePlanId: plan1.weddingPlanId,
        persistedContextKey: plan1.contextKey,
      );
      await harness.controller.refresh();
      harness.api.onList = () => pendingList.future;

      final staleRefresh = harness.controller.refresh();
      final selection = harness.controller.select(plan2.contextKey);
      expect(await selection, isTrue);
      pendingList.complete([plan1, plan2]);
      await staleRefresh;

      expect(harness.controller.selectedContext, plan2);
      expect(harness.storage.readActivePlanId(), plan2.weddingPlanId);
      expect(harness.serverActivePlanId, plan2.weddingPlanId);
    });

    test('newer refresh wins over an older pending validation', () async {
      final plan1 = accountContext(role: AccountContextRole.owner);
      final plan2 = accountContext(
        role: AccountContextRole.contributor,
        planId: 'plan-2',
      );
      final pendingValidation = Completer<AccountContext>();
      final harness = await _Harness.create(
        contexts: [plan1, plan2],
        serverActivePlanId: plan1.weddingPlanId,
        persistedContextKey: plan1.contextKey,
      );
      await harness.controller.refresh();
      harness.api.onValidate = (_) => pendingValidation.future;

      final staleSelection = harness.controller.select(plan2.contextKey);
      final refresh = harness.controller.refresh();
      await refresh;
      pendingValidation.complete(plan2);

      expect(await staleSelection, isFalse);
      expect(harness.controller.selectedContext, plan1);
      expect(harness.storage.readActivePlanId(), plan1.weddingPlanId);
      expect(harness.serverActivePlanId, plan1.weddingPlanId);
    });
  });

  group('AccountContextController authority recovery', () {
    for (final failure in const [
      (
        statusCode: 409,
        serverCode: 'CONTEXT_UNAVAILABLE',
        backendMessage: 'Context is no longer available',
      ),
      (
        statusCode: 404,
        serverCode: 'CONTEXT_NOT_FOUND',
        backendMessage: 'Context not found',
      ),
    ]) {
      test(
        '${failure.statusCode} drops stale authority then requires explicit reselection',
        () async {
          final owner = accountContext(role: AccountContextRole.owner);
          final provider = accountContext(role: AccountContextRole.provider);
          final archived = accountContext(
            role: AccountContextRole.owner,
            lifecycle: 'ARCHIVED',
            accessMode: AccountContextAccessMode.readOnly,
            isAvailable: false,
            unavailableReason: 'PLAN_ARCHIVED',
          );
          final harness = await _Harness.create(
            contexts: [owner, provider],
            serverActivePlanId: owner.weddingPlanId,
            persistedContextKey: owner.contextKey,
          );
          await harness.controller.refresh();
          harness.api.onValidate = (_) async => throw ApiException(
            failure.backendMessage,
            statusCode: failure.statusCode,
            serverCode: failure.serverCode,
          );
          harness.api.onList = () async => [archived, provider];

          final selected = await harness.controller.select(owner.contextKey);

          expect(selected, isFalse);
          expect(harness.api.listCalls, 2);
          expect(harness.controller.contexts, [archived, provider]);
          expect(harness.controller.selectedContext, isNull);
          expect(harness.storage.readAccountContextKey(), isNull);
          expect(harness.controller.needsSelection, isTrue);
          expect(harness.controller.errorMessage, isNull);
          expect(harness.controller.noticeMessage, isNotNull);
          expect(
            harness.controller.noticeMessage,
            isNot(contains(failure.backendMessage)),
          );
          expect(
            harness.controller.noticeMessage,
            isNot(contains(failure.serverCode)),
          );
        },
      );
    }

    test(
      'network or 5xx validation failure preserves authority and attempts a safe relist',
      () async {
        for (final failure in const [
          ApiException('socket leaked', isNetworkFailure: true),
          ApiException(
            'database leaked',
            statusCode: 503,
            serverCode: 'DATABASE_UNAVAILABLE',
          ),
        ]) {
          final owner = accountContext(role: AccountContextRole.owner);
          final provider = accountContext(role: AccountContextRole.provider);
          final harness = await _Harness.create(
            contexts: [owner],
            serverActivePlanId: owner.weddingPlanId,
            persistedContextKey: owner.contextKey,
          );
          await harness.controller.refresh();
          harness.api.onValidate = (_) async => throw failure;
          harness.api.onList = () async => [owner, provider];

          final selected = await harness.controller.select(provider.contextKey);

          expect(selected, isFalse);
          expect(harness.api.listCalls, 2);
          expect(harness.controller.contexts, [owner, provider]);
          expect(harness.controller.selectedContext, owner);
          expect(harness.storage.readAccountContextKey(), owner.contextKey);
          expect(harness.controller.errorMessage, isNotNull);
          expect(
            harness.controller.errorMessage,
            isNot(contains(failure.message)),
          );
          expect(
            harness.controller.errorMessage,
            isNot(contains(failure.serverCode ?? 'socket leaked')),
          );
        }
      },
    );
  });

  group('AccountContextController archived history', () {
    test(
      'opens an already-listed archived plan read-only without making it active',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final archived = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-archived',
          lifecycle: 'ARCHIVED',
          accessMode: AccountContextAccessMode.readOnly,
          isAvailable: false,
          unavailableReason: 'PLAN_ARCHIVED',
        );
        final harness = await _Harness.create(
          contexts: [owner, archived],
          serverActivePlanId: owner.weddingPlanId,
        );
        await harness.controller.refresh();

        final opened = await harness.controller.openReadOnlyContext(
          archived.contextKey,
        );

        expect(opened, isTrue);
        expect(harness.controller.selectedContext, archived);
        expect(harness.storage.readAccountContextKey(), archived.contextKey);
        expect(harness.serverActivePlanId, owner.weddingPlanId);
        expect(harness.storage.readActivePlanId(), isNull);
        expect(harness.setActiveCalls, isEmpty);
      },
    );

    test('refuses a missing or still-writable context as read-only', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final harness = await _Harness.create(contexts: [owner]);
      await harness.controller.refresh(allowInitialSingleContext: true);

      expect(
        await harness.controller.openReadOnlyContext(owner.contextKey),
        isFalse,
      );
      expect(
        await harness.controller.openReadOnlyContext(
          'plan:missing:contributor',
        ),
        isFalse,
      );
      expect(harness.controller.selectedContext, owner);
    });
  });

  group('AccountContextController persistence ambiguity', () {
    test(
      'one local active-plan write failure after server success is reconciled',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final harness = await _Harness.create(
          contexts: [plan1, plan2],
          serverActivePlanId: plan1.weddingPlanId,
          failActivePlanWrites: 1,
        );
        await harness.controller.refresh();

        final selected = await harness.controller.select(plan2.contextKey);

        expect(selected, isTrue);
        expect(harness.serverActivePlanId, plan2.weddingPlanId);
        expect(harness.storage.readActivePlanId(), plan2.weddingPlanId);
        expect(harness.storage.readAccountContextKey(), plan2.contextKey);
        expect(harness.controller.selectedContext, plan2);
      },
    );
  });

  group('AccountContextController disposal safety', () {
    test(
      'dispose invalidates a pending list without notifying later',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final pending = Completer<List<AccountContext>>();
        final harness = await _Harness.create(contexts: [owner]);
        harness.api.onList = () => pending.future;
        var notifications = 0;
        harness.controller.addListener(() => notifications += 1);

        final refresh = harness.controller.refresh();
        expect(notifications, 1);
        harness.controller.dispose();
        pending.complete([owner]);

        await expectLater(refresh, completes);
        expect(notifications, 1);
        expect(harness.controller.selectedContext, isNull);
      },
    );

    test(
      'dispose invalidates a pending validation without notifying later',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final provider = accountContext(role: AccountContextRole.provider);
        final pending = Completer<AccountContext>();
        final harness = await _Harness.create(contexts: [owner, provider]);
        await harness.storage.saveAccountContextKey(owner.contextKey);
        await harness.controller.refresh();
        harness.api.onValidate = (_) => pending.future;
        var notifications = 0;
        harness.controller.addListener(() => notifications += 1);

        final selection = harness.controller.select(provider.contextKey);
        expect(notifications, 1);
        harness.controller.dispose();
        pending.complete(provider);

        expect(await selection, isFalse);
        expect(notifications, 1);
        expect(harness.controller.selectedContext, owner);
      },
    );

    test(
      'dispose invalidates a pending set-active without notifying or persisting later',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final pending = Completer<void>();
        final harness = await _Harness.create(
          contexts: [plan1, plan2],
          serverActivePlanId: plan1.weddingPlanId,
          persistedContextKey: plan1.contextKey,
          onSetActive: (_) => pending.future,
        );
        await harness.controller.refresh();
        var notifications = 0;
        harness.controller.addListener(() => notifications += 1);

        final selection = harness.controller.select(plan2.contextKey);
        await _flush();
        expect(notifications, 1);
        harness.controller.dispose();
        pending.complete();

        expect(await selection, isFalse);
        expect(notifications, 1);
        expect(harness.storage.readActivePlanId(), plan1.weddingPlanId);
        expect(harness.storage.readAccountContextKey(), plan1.contextKey);
      },
    );
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Harness {
  _Harness._({
    required this.api,
    required this.storage,
    required this.controller,
    required this.setActiveCalls,
    required String? initialServerActivePlanId,
  }) : serverActivePlanId = initialServerActivePlanId;

  final _FakeContextsApi api;
  final AuthStorage storage;
  final AccountContextController controller;
  final List<String> setActiveCalls;
  String? serverActivePlanId;

  static Future<_Harness> create({
    required List<AccountContext> contexts,
    String? serverActivePlanId,
    String? persistedContextKey,
    Future<void> Function(String planId)? onSetActive,
    int failActivePlanWrites = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      'aarast_active_plan_id': ?serverActivePlanId,
      'aarast_account_context_key': ?persistedContextKey,
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailOnceAuthStorage(
      preferences,
      failActivePlanWrites: failActivePlanWrites,
    );
    final api = _FakeContextsApi(contexts);
    final calls = <String>[];
    late _Harness harness;
    final controller = AccountContextController(
      contextsApi: api,
      authStorage: storage,
      readActiveWeddingPlanId: () async => harness.serverActivePlanId,
      setActiveWeddingPlan: (planId) async {
        calls.add(planId);
        harness.serverActivePlanId = planId;
        await onSetActive?.call(planId);
      },
    );
    harness = _Harness._(
      api: api,
      storage: storage,
      controller: controller,
      setActiveCalls: calls,
      initialServerActivePlanId: serverActivePlanId,
    );
    return harness;
  }
}

class _FailOnceAuthStorage extends AuthStorage {
  _FailOnceAuthStorage(super.preferences, {required this.failActivePlanWrites});

  int failActivePlanWrites;

  @override
  Future<void> saveActivePlanId(String activePlanId) async {
    if (failActivePlanWrites > 0) {
      failActivePlanWrites -= 1;
      throw TimeoutException('simulated local persistence timeout');
    }
    await super.saveActivePlanId(activePlanId);
  }
}

class _FakeContextsApi implements AccountContextsGateway {
  _FakeContextsApi(List<AccountContext> contexts)
    : onList = (() async => contexts),
      onValidate = ((key) async {
        return contexts.firstWhere((context) => context.contextKey == key);
      });

  Future<List<AccountContext>> Function() onList;
  Future<AccountContext> Function(String contextKey) onValidate;
  int listCalls = 0;

  @override
  Future<List<AccountContext>> listContexts() {
    listCalls += 1;
    return onList();
  }

  @override
  Future<AccountContext> validateContext(String contextKey) {
    return onValidate(contextKey);
  }
}
