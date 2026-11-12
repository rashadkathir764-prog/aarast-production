import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

const _offline = ApiException('offline', isNetworkFailure: true);

/// A signed-in user's storage whose last opened context was [opened].
Future<AuthStorage> _signedInStorage({
  required String userId,
  AccountContext? opened,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: 'token',
    user: SafeUser(
      id: userId,
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  if (opened != null) {
    await storage.saveAccountContextKey(
      opened.contextKey,
      context: opened.toJson(),
    );
  }
  return storage;
}

AccountContextController _offlineController(
  AuthStorage storage, {
  Set<String> leaving = const {},
  ApiException failure = _offline,
}) {
  return AccountContextController(
    contextsApi: _FakeContextsApi(const [])..onList = () async => throw failure,
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
    beforeRefresh: () async => leaving,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('opening without a connection', () {
    test('a context reads back exactly from its kept copy', () {
      for (final context in [
        accountContext(role: AccountContextRole.owner),
        accountContext(
          role: AccountContextRole.contributor,
          membershipId: 'membership-1',
        ),
        accountContext(role: AccountContextRole.provider),
      ]) {
        final copy = AccountContext.fromJson(context.toJson());
        expect(copy.toJson(), context.toJson());
      }
    });

    test(
      'the owner opens the plan last opened, with an offline notice',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final storage = await _signedInStorage(userId: 'user-1', opened: owner);
        final controller = _offlineController(storage);

        await controller.refresh(allowInitialSingleContext: true);

        expect(controller.errorMessage, isNull);
        expect(controller.selectedContext?.contextKey, owner.contextKey);
        expect(controller.hasLoadedContexts, isTrue);
        expect(controller.noticeMessage, contains('أنت بدون نت'));
      },
    );

    test('nothing kept says the server cannot be reached', () async {
      final storage = await _signedInStorage(userId: 'user-1');
      final controller = _offlineController(storage);

      await controller.refresh(allowInitialSingleContext: true);

      expect(controller.selectedContext, isNull);
      expect(controller.errorMessage, contains('ما وصلنا للخادم'));
    });

    test('a contributor copy is never opened offline', () async {
      final contributor = accountContext(
        role: AccountContextRole.contributor,
        membershipId: 'membership-1',
      );
      final storage = await _signedInStorage(
        userId: 'user-1',
        opened: contributor,
      );
      final controller = _offlineController(storage);

      await controller.refresh(allowInitialSingleContext: true);

      expect(controller.selectedContext, isNull);
      expect(controller.errorMessage, isNotNull);
    });

    test('a plan being left is never opened offline', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final storage = await _signedInStorage(userId: 'user-1', opened: owner);
      final controller = _offlineController(storage, leaving: {'plan-1'});

      await controller.refresh(allowInitialSingleContext: true);

      expect(controller.selectedContext, isNull);
      expect(controller.errorMessage, isNotNull);
    });

    test('another account never opens the copy', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final storage = await _signedInStorage(userId: 'user-1', opened: owner);
      await storage.saveSession(
        accessToken: 'other',
        user: const SafeUser(
          id: 'user-2',
          name: 'غيره',
          role: 'CUSTOMER',
          status: 'ACTIVE',
        ),
      );
      final controller = _offlineController(storage);

      await controller.refresh(allowInitialSingleContext: true);

      expect(controller.selectedContext, isNull);
      expect(storage.readAccountContextSnapshot(), isNull);
    });

    test('a server refusal is not treated as offline', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final storage = await _signedInStorage(userId: 'user-1', opened: owner);
      final controller = _offlineController(
        storage,
        failure: const ApiException('down', statusCode: 500),
      );

      await controller.refresh(allowInitialSingleContext: true);

      expect(controller.selectedContext, isNull);
      expect(controller.errorMessage, isNotNull);
    });

    test('signing out drops the kept copy', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final storage = await _signedInStorage(userId: 'user-1', opened: owner);
      expect(storage.readAccountContextSnapshot(), isNotNull);

      await storage.clear();

      expect(storage.readAccountContextSnapshot(), isNull);
    });
  });

  group('AccountContextController fallback and persistence', () {
    test('a plan just saved from the phone opens without a chooser', () async {
      final saved = accountContext(role: AccountContextRole.owner);
      final contexts = <AccountContext>[];
      final harness = await _Harness.create(contexts: contexts);
      harness.api.onList = () async => List.of(contexts);
      // Sign-in loads the account before the phone plan reaches it.
      await harness.controller.refresh(allowInitialSingleContext: true);
      expect(harness.controller.selectedContext, isNull);

      contexts.add(saved);
      await harness.controller.refreshAndOpenPlan('plan-1');

      expect(harness.controller.selectedContext?.contextKey, saved.contextKey);
      expect(harness.controller.needsSelection, isFalse);
    });

    test('opening a saved plan picks it among other paths', () async {
      final other = accountContext(
        role: AccountContextRole.contributor,
        planId: 'plan-2',
        membershipId: 'membership-2',
      );
      final saved = accountContext(role: AccountContextRole.owner);
      final harness = await _Harness.create(contexts: [other, saved]);

      await harness.controller.refreshAndOpenPlan('plan-1');

      expect(harness.controller.selectedContext?.contextKey, saved.contextKey);
    });

    test(
      'loads every account path without choosing among multiple paths',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final contributor = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(
          contexts: [owner, contributor, provider],
        );

        await harness.controller.refresh();

        expect(harness.controller.contexts, [owner, contributor, provider]);
        expect(harness.controller.selectedContext, isNull);
        expect(harness.controller.availableContexts, [
          owner,
          contributor,
          provider,
        ]);
        expect(harness.controller.needsSelection, isTrue);
      },
    );

    test(
      'only current or persisted selection may bypass multi-path selection',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final contributor = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(
          contexts: [owner, contributor, provider],
          persistedKey: contributor.contextKey,
        );

        await harness.controller.refresh();
        expect(harness.controller.selectedContext, contributor);

        await harness.storage.saveAccountContextKey(owner.contextKey);
        await harness.controller.refresh();
        expect(
          harness.controller.selectedContext,
          contributor,
          reason: 'a still-valid current context wins over changed persistence',
        );

        final activeHarness = await _Harness.create(
          contexts: [owner, contributor, provider],
        );
        await activeHarness.controller.refresh();
        expect(activeHarness.controller.selectedContext, isNull);
        expect(activeHarness.controller.needsSelection, isTrue);

        final roleHarness = await _Harness.create(
          contexts: [provider, contributor, owner],
        );
        await roleHarness.controller.refresh();
        expect(roleHarness.controller.selectedContext, isNull);
        expect(roleHarness.controller.needsSelection, isTrue);
      },
    );

    test(
      'an omitted activeWeddingPlanId does not revive a stale legacy plan id',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final contributor = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final harness = await _Harness.create(
          contexts: [owner, contributor],
          activePlanId: contributor.weddingPlanId,
        );

        await harness.controller.refresh();

        expect(harness.controller.selectedContext, isNull);
        expect(harness.controller.needsSelection, isTrue);
      },
    );

    test(
      'invalid saved path requires selection unless one path remains',
      () async {
        final archivedOwner = accountContext(
          role: AccountContextRole.owner,
          lifecycle: 'ARCHIVED',
          accessMode: AccountContextAccessMode.readOnly,
          isAvailable: false,
          unavailableReason: 'PLAN_ARCHIVED',
        );
        final contributor = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(
          contexts: [provider, contributor, archivedOwner],
        );

        await harness.controller.refresh();
        expect(harness.controller.selectedContext, isNull);
        expect(harness.controller.needsSelection, isTrue);

        harness.api.onList = () async => [provider, archivedOwner];
        await harness.controller.clearForLogout();
        await harness.storage.saveAccountContextKey(archivedOwner.contextKey);
        await harness.controller.refresh();
        expect(
          harness.controller.selectedContext,
          isNull,
          reason: 'an invalid saved path must never choose a replacement path',
        );
        expect(harness.controller.needsSelection, isTrue);
      },
    );

    test(
      'plan selection validates, sets active once, and persists both keys',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final harness = await _Harness.create(contexts: [owner]);
        await harness.controller.refresh(allowInitialSingleContext: true);

        final selected = await harness.controller.select(owner.contextKey);

        expect(selected, isTrue);
        expect(harness.api.validatedKeys, [owner.contextKey]);
        expect(harness.setActiveCalls, [owner.weddingPlanId]);
        expect(harness.storage.readAccountContextKey(), owner.contextKey);
        expect(harness.storage.readActivePlanId(), owner.weddingPlanId);
      },
    );

    test(
      'provider selection validates without changing the active plan',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(
          contexts: [owner, provider],
          activePlanId: owner.weddingPlanId,
        );
        await harness.controller.refresh();

        final selected = await harness.controller.select(provider.contextKey);

        expect(selected, isTrue);
        expect(harness.api.validatedKeys, [provider.contextKey]);
        expect(harness.setActiveCalls, isEmpty);
        expect(harness.storage.readActivePlanId(), isNull);
        expect(harness.storage.readAccountContextKey(), provider.contextKey);
      },
    );
  });

  group('AccountContextController refresh truth', () {
    test(
      'refresh preserves selection while adding a provider context',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(contexts: [owner]);
        await harness.controller.refresh(allowInitialSingleContext: true);
        harness.api.onList = () async => [owner, provider];

        await harness.controller.refresh(allowInitialSingleContext: true);

        expect(harness.controller.selectedContext, owner);
        expect(harness.controller.contexts, [owner, provider]);
      },
    );

    test(
      'network refresh failure keeps the owner plan open and says offline',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final harness = await _Harness.create(contexts: [owner]);
        await harness.controller.refresh(allowInitialSingleContext: true);
        harness.api.onList = () async => throw _offline;

        await harness.controller.refresh();

        expect(harness.controller.contexts, [owner]);
        expect(harness.controller.selectedContext, owner);
        expect(harness.controller.errorMessage, isNull);
        expect(harness.controller.noticeMessage, contains('أنت بدون نت'));
      },
    );

    test('network refresh failure still fails a contributor closed', () async {
      final contributor = accountContext(
        role: AccountContextRole.contributor,
        membershipId: 'membership-1',
      );
      final harness = await _Harness.create(contexts: [contributor]);
      await harness.controller.refresh(allowInitialSingleContext: true);
      harness.api.onList = () async => throw _offline;

      await harness.controller.refresh();

      expect(harness.controller.errorMessage, isNotNull);
    });

    test(
      'archive or revocation clears selection with a generic notice',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final provider = accountContext(role: AccountContextRole.provider);
        final harness = await _Harness.create(
          contexts: [owner, provider],
          persistedKey: owner.contextKey,
        );
        await harness.controller.refresh();
        final archived = accountContext(
          role: AccountContextRole.owner,
          lifecycle: 'ARCHIVED',
          accessMode: AccountContextAccessMode.readOnly,
          isAvailable: false,
          unavailableReason: 'PLAN_ARCHIVED',
        );
        harness.api.onList = () async => [archived, provider];

        await harness.controller.refresh();

        expect(harness.controller.selectedContext, isNull);
        expect(harness.controller.needsSelection, isTrue);
        expect(harness.controller.noticeMessage, isNotNull);
        expect(harness.controller.noticeMessage, isNot(contains('plan-1')));
        expect(
          harness.controller.noticeMessage,
          isNot(contains('PLAN_ARCHIVED')),
        );
      },
    );
  });

  group('AccountContextController stale async protection', () {
    test('an older refresh cannot overwrite a newer refresh', () async {
      final first = Completer<List<AccountContext>>();
      final second = Completer<List<AccountContext>>();
      var call = 0;
      final harness = await _Harness.create(contexts: const []);
      harness.api.onList = () => call++ == 0 ? first.future : second.future;
      final owner = accountContext(role: AccountContextRole.owner);
      final provider = accountContext(role: AccountContextRole.provider);

      final older = harness.controller.refresh();
      final newer = harness.controller.refresh(allowInitialSingleContext: true);
      second.complete([provider]);
      await newer;
      first.complete([owner]);
      await older;

      expect(harness.controller.contexts, [provider]);
      expect(harness.controller.selectedContext, provider);
    });

    test(
      'an older validation cannot set active or overwrite newer selection',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final first = Completer<AccountContext>();
        final second = Completer<AccountContext>();
        final harness = await _Harness.create(contexts: [plan1, plan2]);
        await harness.controller.refresh();
        harness.api.onValidate = (key) =>
            key == plan1.contextKey ? first.future : second.future;

        final older = harness.controller.select(plan1.contextKey);
        final newer = harness.controller.select(plan2.contextKey);
        second.complete(plan2);
        expect(await newer, isTrue);
        first.complete(plan1);
        expect(await older, isFalse);

        expect(harness.setActiveCalls, [plan2.weddingPlanId]);
        expect(harness.controller.selectedContext, plan2);
      },
    );

    test(
      'queued plan selections make the newest server mutation finish last',
      () async {
        final plan1 = accountContext(role: AccountContextRole.owner);
        final plan2 = accountContext(
          role: AccountContextRole.contributor,
          planId: 'plan-2',
        );
        final firstSet = Completer<void>();
        final secondSet = Completer<void>();
        final harness = await _Harness.create(
          contexts: [plan1, plan2],
          onSetActive: (planId) {
            if (planId == plan1.weddingPlanId) return firstSet.future;
            return secondSet.future;
          },
        );
        await harness.controller.refresh();

        final older = harness.controller.select(plan1.contextKey);
        await _flush();
        expect(harness.setActiveCalls, [plan1.weddingPlanId]);
        final newer = harness.controller.select(plan2.contextKey);
        await _flush();
        expect(
          harness.setActiveCalls,
          [plan1.weddingPlanId],
          reason: 'the newest set-active waits for the older request',
        );

        firstSet.complete();
        await _flush();
        expect(harness.setActiveCalls, [
          plan1.weddingPlanId,
          plan2.weddingPlanId,
        ]);
        secondSet.complete();
        expect(await older, isFalse);
        expect(await newer, isTrue);
        expect(harness.controller.selectedContext, plan2);
      },
    );

    test('logout clears state and invalidates an in-flight refresh', () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final provider = accountContext(role: AccountContextRole.provider);
      final pending = Completer<List<AccountContext>>();
      final harness = await _Harness.create(contexts: [owner]);
      await harness.controller.refresh();
      harness.api.onList = () => pending.future;
      final refresh = harness.controller.refresh();

      await harness.controller.clearForLogout();
      pending.complete([provider]);
      await refresh;

      expect(harness.controller.contexts, isEmpty);
      expect(harness.controller.selectedContext, isNull);
      expect(harness.storage.readAccountContextKey(), isNull);
    });

    test(
      'logout hides context state before an in-flight selection finishes',
      () async {
        final owner = accountContext(role: AccountContextRole.owner);
        final pendingSetActive = Completer<void>();
        final harness = await _Harness.create(
          contexts: [owner],
          onSetActive: (_) => pendingSetActive.future,
        );
        await harness.controller.refresh();
        final selection = harness.controller.select(owner.contextKey);
        await _flush();

        final logout = harness.controller.clearForLogout();
        await _flush();
        final clearedImmediately =
            harness.controller.contexts.isEmpty &&
            harness.controller.selectedContext == null;
        pendingSetActive.complete();
        await selection;
        await logout;

        expect(clearedImmediately, isTrue);
        expect(harness.controller.contexts, isEmpty);
        expect(harness.controller.selectedContext, isNull);
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
  });

  final _FakeContextsApi api;
  final AuthStorage storage;
  final AccountContextController controller;
  final List<String> setActiveCalls;

  static Future<_Harness> create({
    required List<AccountContext> contexts,
    String? persistedKey,
    String? activePlanId,
    Future<void> Function(String planId)? onSetActive,
  }) async {
    SharedPreferences.setMockInitialValues({
      'aarast_account_context_key': ?persistedKey,
      'aarast_active_plan_id': ?activePlanId,
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final api = _FakeContextsApi(contexts);
    final calls = <String>[];
    final controller = AccountContextController(
      contextsApi: api,
      authStorage: storage,
      setActiveWeddingPlan: (planId) async {
        calls.add(planId);
        await onSetActive?.call(planId);
      },
    );
    return _Harness._(
      api: api,
      storage: storage,
      controller: controller,
      setActiveCalls: calls,
    );
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
  final List<String> validatedKeys = [];

  @override
  Future<List<AccountContext>> listContexts() => onList();

  @override
  Future<AccountContext> validateContext(String contextKey) {
    validatedKeys.add(contextKey);
    return onValidate(contextKey);
  }
}
