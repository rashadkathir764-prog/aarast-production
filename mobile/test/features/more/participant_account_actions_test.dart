import 'dart:async';

import 'package:aarast_mobile/app.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/pending_plan_cleanup.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/sharing/screens/participant_plan_state_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/services/plan_leave_coordinator.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'leave intent is durable before DELETE and survives cache wipe for replay',
    () async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      const requestId = '11111111-1111-4111-8111-111111111111';
      var markerWasDurableBeforeRequest = false;
      harness.sharing
        ..failuresRemaining = 1
        ..failure = const ApiException(
          'controlled network failure',
          isNetworkFailure: true,
        )
        ..beforeLeave = () async {
          final records = await harness.pendingPlanCleanupStore.readAll();
          markerWasDurableBeforeRequest =
              records.length == 1 &&
              records.single.clientRequestId == requestId;
        };

      await harness.planLeaveCoordinator.leavePlan(
        userId: 'contributor-user',
        weddingPlanId: 'shared-plan',
        expectedMemberId: 'member-shared-plan',
        expectedAuthorityVersion: 1,
        clientRequestId: requestId,
        refreshAccountContexts: () async {},
      );

      expect(markerWasDurableBeforeRequest, isTrue);
      final originalRecord =
          (await harness.pendingPlanCleanupStore.readAll()).single;
      expect(originalRecord.clientRequestId, requestId);
      expect(originalRecord.expectedMemberId, 'member-shared-plan');
      expect(originalRecord.expectedAuthorityVersion, 1);

      await harness.offline.clearLocalData();
      final afterCacheWipe =
          (await harness.pendingPlanCleanupStore.readAll()).single;
      expect(afterCacheWipe.installationId, originalRecord.installationId);
      expect(afterCacheWipe.clientRequestId, requestId);

      await harness.offline.ensureCacheOwner('contributor-user');
      final restartedStore = PendingPlanCleanupStore(
        await SharedPreferences.getInstance(),
      );
      final restartedCoordinator = PlanLeaveCoordinator(
        sharingApi: harness.sharing,
        offlineSync: harness.offline,
        store: restartedStore,
      );
      final hiddenPlanIds = await restartedCoordinator.preparePendingForUser(
        'contributor-user',
      );

      expect(hiddenPlanIds, {'shared-plan'});
      expect(harness.sharing.requestIds, [requestId, requestId]);
      expect(await restartedStore.readAll(), hasLength(1));

      await restartedCoordinator.completeAfterContextsRefreshForUser(
        'contributor-user',
      );
      expect(await restartedStore.readAll(), isEmpty);
      // releasePlanQuarantine schedules the remaining non-plan queue replay.
      // Let that owned async task finish before disposing the notifier.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
  );

  test(
    'permanent account cleanup removes only that user leave markers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PendingPlanCleanupStore(
        await SharedPreferences.getInstance(),
      );
      await store.putIfAbsent(
        userId: 'deleted-user',
        planId: 'deleted-user-plan',
        expectedMemberId: 'deleted-member',
        expectedAuthorityVersion: 1,
        clientRequestId: '22222222-2222-4222-8222-222222222222',
      );
      await store.putIfAbsent(
        userId: 'other-user',
        planId: 'other-user-plan',
        expectedMemberId: 'other-member',
        expectedAuthorityVersion: 2,
        clientRequestId: '33333333-3333-4333-8333-333333333333',
      );

      await store.removeForUser('deleted-user');

      final records = await store.readAll();
      expect(records, hasLength(1));
      expect(records.single.userId, 'other-user');
      expect(records.single.planId, 'other-user-plan');
    },
  );

  test('malformed durable leave marker fails closed', () async {
    SharedPreferences.setMockInitialValues({
      PendingPlanCleanupStore.storageKey:
          '{"version":2,"installationId":"install-a","records":['
          '{"installationId":"install-a","userId":7,"planId":"plan-a",'
          '"expectedMemberId":"member-a","expectedAuthorityVersion":1,'
          '"clientRequestId":"44444444-4444-4444-8444-444444444444",'
          '"createdAt":"2026-08-03T00:00:00.000Z"}]}',
    });
    final store = PendingPlanCleanupStore(
      await SharedPreferences.getInstance(),
    );

    await expectLater(store.readAll(), throwsA(isA<FormatException>()));
  });

  testWidgets('q10 lists the plans helped in, your own plan and the open one', (
    tester,
  ) async {
    final harness = await _ContributorActionHarness.create(withArchived: true);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('مساهم · 777 123 456'), findsOneWidget);
    expect(find.text('الخطط اللي أشارك فيها'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('participant-plan-plan:shared-plan:contributor'),
      ),
      findsOneWidget,
    );
    // The flags the plan opens: tasks and guests, no money.
    expect(find.text('المهام والضيوف'), findsOneWidget);
    expect(find.text('في الذكريات'), findsOneWidget);
    expect(find.text('خطتي'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('participant-plan-plan:owner-plan:owner')),
      findsOneWidget,
    );
    expect(find.text('في عرس المشارك'), findsOneWidget);
    expect(find.text('اللي سجّلته'), findsOneWidget);
    expect(find.text('اطلع من الخطة'), findsOneWidget);
    // The owner's profile card and «عرسي» are not the participant's.
    expect(find.byTooltip('تعديل صورة الحساب'), findsNothing);
    expect(find.text('عرسي'), findsNothing);
    // q10 lists the plans, so g02's «خططك» row is not repeated.
    expect(find.byKey(const ValueKey('account-plans')), findsNothing);
    // C4: deleting the account waits for its 30-day grace, as for the owner.
    await tester.scrollUntilVisible(
      find.text('الخروج'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('حذف الحساب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a plan of their own q10 offers to start one', (
    tester,
  ) async {
    final harness = await _ContributorActionHarness.create(withOwner: false);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text('ابدأ خطة عرسك'), findsOneWidget);
    expect(find.text('بنفس حسابك'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('participant-start-own-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-plan-destination')), findsOneWidget);
  });

  testWidgets('another path opens from q10 without signing in again', (
    tester,
  ) async {
    final harness = await _ContributorActionHarness.create();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('participant-plan-plan:owner-plan:owner')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
    expect(
      harness.contexts.selectedContext?.contextKey,
      'plan:owner-plan:owner',
    );
    expect(await harness.storage.readAccessToken(), 'session-token');
    expect(tester.takeException(), isNull);
  });

  testWidgets('q19: a plan in the memories says so, read only', (tester) async {
    final harness = await _ContributorActionHarness.create(withArchived: true);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('participant-plan-plan:old-plan:contributor')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('participant-plan-plan:old-plan:contributor')),
    );
    await tester.pumpAndSettle();

    expect(find.text('عرس قديم'), findsOneWidget);
    expect(find.text('لما الخطة تتغير'), findsOneWidget);
    expect(find.text('الخطة في الذكريات'), findsOneWidget);
    // J2-20: the owner by the plan's word; the wedding is not assumed done.
    expect(
      find.text('الخطة في الذكريات: العريس حفظها هناك.'),
      findsOneWidget,
    );
    expect(find.textContaining('صاحب الخطة'), findsNothing);
    expect(find.textContaining('العرس تم'), findsNothing);
    // Paused, postponed and deleted wait for the plan states (q19).
    expect(find.text('الخطة متوقفة'), findsNothing);
    expect(find.text('الخطة انحذفت'), findsNothing);
    // The archived plan never becomes the open one.
    expect(
      harness.contexts.selectedContext?.contextKey,
      'plan:shared-plan:contributor',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'J2-07: a participant taken off the plan is told so, by name',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      // The owner took them off; the phone still holds the old path when
      // the notice opens.
      harness.contextsGateway.contexts.removeWhere(
        (context) => context.weddingPlanId == 'shared-plan',
      );
      harness.router.go('/shared/wedding-plans/shared-plan');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('participant-plan-removed')),
        findsOneWidget,
      );
      expect(
        find.text('العريس شالك من عرس المشارك. اللي سجّلته قبل يبقى باسمك.'),
        findsOneWidget,
      );
      expect(find.text('ما فيه تغيير على هذي الخطة'), findsNothing);
      // The path is gone from the phone too.
      expect(harness.contexts.selectedContext, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J2-07: a notice for a plan the phone never knew still says it plainly',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      harness.router.go('/shared/wedding-plans/unknown-plan');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('participant-plan-removed')),
        findsOneWidget,
      );
      expect(
        find.text('ما عاد لك مكان في هذي الخطة. اللي سجّلته قبل يبقى باسمك.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J2-10: a leave refused after a rights change refreshes and leaves once',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      harness.sharing
        ..failuresRemaining = 1
        ..failure = _membershipChanged;
      await harness.pump(tester);

      await _openLeave(tester);
      // The owner changed the rights while the sheet was open.
      harness.bumpContributorAuthority();
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(harness.sharing.versions, [1, 2]);
      expect(harness.sharing.requestIds, hasLength(2));
      expect(harness.sharing.requestIds.toSet(), hasLength(2));
      expect(
        find.byKey(const ValueKey('participant-leave-error')),
        findsNothing,
      );
      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(harness.contexts.selectedContext, isNull);
      expect(find.text('طلعت من عرس المشارك'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J2-10: a second refusal says what happened and never blames the net',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      harness.sharing
        ..failuresRemaining = 2
        ..failure = _membershipChanged;
      await harness.pump(tester);

      await _openLeave(tester);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(harness.sharing.requestIds, hasLength(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('participant-leave-error')),
          matching: find.text(
            'تغيّرت صلاحياتك قبل شوي، حدّثنا الخطة. جرّب الخروج مرة ثانية.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('النت'), findsNothing);
      expect(harness.contexts.selectedContext?.weddingPlanId, 'shared-plan');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('J2-10: any other refusal is said as the server said it', (
    tester,
  ) async {
    final harness = await _ContributorActionHarness.create();
    addTearDown(harness.dispose);
    harness.sharing
      ..failuresRemaining = 1
      ..failure = const ApiException(
        'ما عاد لك مكان في هذي الخطة.',
        statusCode: 403,
      );
    await harness.pump(tester);

    await _openLeave(tester);
    await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
    await tester.pumpAndSettle();

    expect(harness.sharing.requestIds, hasLength(1));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('participant-leave-error')),
        matching: find.text('ما عاد لك مكان في هذي الخطة.'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('النت'), findsNothing);
  });

  testWidgets(
    'account logout from «حسابي» clears the session and opens login',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await tester.scrollUntilVisible(
        find.text('الخروج'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('الخروج'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-logout-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-destination')), findsOneWidget);
      expect(harness.storage.readAccountContextKey(), isNull);
      expect(await harness.storage.readAccessToken(), isNull);
      expect(await harness.storage.readRefreshToken(), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming the participant shell refreshes account-context authority',
    (tester) async {
      final harness = await _ContributorActionHarness.create(
        initialLocation: '/shell',
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);
      final callsBeforeResume = harness.contextsGateway.listCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(harness.contextsGateway.listCalls, greaterThan(callsBeforeResume));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan leave keeps context on failure and retries with the same request id',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      harness.sharing.failuresRemaining = 1;
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await _openLeave(tester);
      expect(find.byType(JourneySheetBody), findsOneWidget);
      expect(find.text('تطلع من عرس المشارك؟'), findsOneWidget);
      expect(find.text('تقدر ترجع لو أرسل لك دعوة ثانية'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('participant-leave-error')),
        findsOneWidget,
      );
      expect(harness.contexts.selectedContext?.weddingPlanId, 'shared-plan');
      expect(harness.offline.clearPlanCalls, isEmpty);
      expect(await harness.pendingPlanCleanupStore.readAll(), isEmpty);

      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(harness.contexts.selectedContext, isNull);
      expect(harness.sharing.requestIds, hasLength(2));
      expect(harness.sharing.requestIds.toSet(), hasLength(1));
      expect(harness.offline.clearPlanCalls, ['shared-plan']);
      expect(await harness.pendingPlanCleanupStore.readAll(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful plan leave clears only its offline graph before refresh and navigation',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      await harness.seedOfflinePlanGraphs();
      await harness.pump(tester);
      final refreshCallsBeforeLeave = harness.contextsGateway.listCalls;
      harness.offline.pauseNextPlanClear();

      await _openLeave(tester);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pump();
      await tester.pump();

      expect(harness.sharing.requestIds, hasLength(1));
      expect(harness.offline.clearPlanCalls, ['shared-plan']);
      expect(harness.contextsGateway.listCalls, refreshCallsBeforeLeave);
      expect(find.byKey(const Key('path-choice-destination')), findsNothing);
      expect(await harness.pendingPlanCleanupStore.readAll(), hasLength(1));

      harness.contextsGateway.pauseNextList();
      harness.offline.releasePlanClear();
      await tester.pump();
      await tester.pump();

      expect(
        harness.contextsGateway.listCalls,
        greaterThan(refreshCallsBeforeLeave),
      );
      expect(await harness.pendingPlanCleanupStore.readAll(), hasLength(1));
      expect(find.byKey(const Key('path-choice-destination')), findsNothing);

      harness.contextsGateway.releaseList();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(harness.contexts.selectedContext, isNull);
      expect(
        harness.contexts.contexts.any(
          (context) => context.weddingPlanId == 'shared-plan',
        ),
        isFalse,
      );
      expect(await harness.pendingPlanCleanupStore.readAll(), isEmpty);
      expect(await harness.storage.readAccessToken(), 'session-token');
      expect(
        await harness.offline.database.getMeta('cache_owner_user_id'),
        'contributor-user',
      );

      final plans = await harness.offline.database.readCachedList(
        table: OfflineTables.cachedWeddingPlans,
      );
      expect(plans.map((row) => row['id']), ['owner-plan']);
      final tasks = await harness.offline.database.readCachedList(
        table: OfflineTables.cachedTasks,
      );
      expect(tasks.map((row) => row['id']), ['owner-task']);
      final queued = await harness.offline.database.pendingSyncItems();
      expect(queued, hasLength(1));
      expect(queued.single.endpoint, contains('/owner-plan/'));
      expect(
        await harness.offline.database.readCachedItem(
          table: OfflineTables.currentUserProfile,
          id: 'contributor-user',
        ),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan context is invalidated even when the leave screen unmounts in flight',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      final leaveRelease = Completer<void>();
      harness.sharing.beforeLeave = () => leaveRelease.future;
      await harness.pump(tester);

      await _openLeave(tester);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pump();
      await tester.pump();
      expect(harness.sharing.requestIds, hasLength(1));

      harness.router.go(AppRouter.home);
      await tester.pumpAndSettle();
      leaveRelease.complete();
      await tester.pumpAndSettle();

      expect(harness.contexts.selectedContext, isNull);
      expect(harness.storage.readAccountContextKey(), isNull);
      expect(
        harness.contexts.contexts.any(
          (context) => context.weddingPlanId == 'shared-plan',
        ),
        isFalse,
      );
      expect(await harness.pendingPlanCleanupStore.readAll(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server-confirmed leave retries local cleanup before exposing contexts',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      harness.offline.failNextPlanClear = true;
      await harness.pump(tester);

      await _openLeave(tester);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(harness.sharing.requestIds, hasLength(2));
      expect(harness.sharing.requestIds.toSet(), hasLength(1));
      expect(harness.offline.clearPlanCalls, ['shared-plan', 'shared-plan']);
      expect(await harness.pendingPlanCleanupStore.readAll(), isEmpty);
      expect(harness.contexts.selectedContext, isNull);
      expect(
        harness.contexts.contexts.any(
          (context) => context.weddingPlanId == 'shared-plan',
        ),
        isFalse,
      );
      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ambiguous leave stays durable and hides the plan while replay is pending',
    (tester) async {
      final harness = await _ContributorActionHarness.create();
      addTearDown(harness.dispose);
      harness.sharing
        ..failuresRemaining = 2
        ..failure = const ApiException(
          'controlled network failure',
          isNetworkFailure: true,
        );
      await harness.pump(tester);

      await _openLeave(tester);
      await tester.tap(find.byKey(const ValueKey('participant-leave-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('path-choice-destination')), findsOneWidget);
      expect(harness.sharing.requestIds, hasLength(2));
      expect(harness.sharing.requestIds.toSet(), hasLength(1));
      expect(await harness.pendingPlanCleanupStore.readAll(), hasLength(1));
      expect(harness.contexts.selectedContext, isNull);
      expect(
        harness.contexts.contexts.any(
          (context) => context.weddingPlanId == 'shared-plan',
        ),
        isFalse,
      );
      expect(harness.offline.clearPlanCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a guarded participant shell refreshes once without a remount loop',
    (tester) async {
      final harness = await _ContributorActionHarness.create(
        initialLocation: '/guarded-workspace',
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      final callsBeforeResume = harness.contextsGateway.listCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(harness.contextsGateway.listCalls, callsBeforeResume + 1);
      expect(tester.takeException(), isNull);
    },
  );
}

const _membershipChanged = ApiException(
  'تغيّرت صلاحياتك قبل شوي، حدّثنا الخطة. جرّب الخروج مرة ثانية.',
  statusCode: 409,
  serverCode: 'MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST',
);

Future<void> _openLeave(WidgetTester tester) async {
  final leave = find.byKey(const ValueKey('participant-leave'));
  await tester.ensureVisible(leave);
  await tester.pumpAndSettle();
  await tester.tap(leave);
  await tester.pumpAndSettle();
}

class _ContributorActionHarness {
  _ContributorActionHarness({
    required this.storage,
    required this.contextsGateway,
    required this.contexts,
    required this.auth,
    required this.authRepository,
    required this.offline,
    required this.weddingPlans,
    required this.dashboard,
    required this.sharing,
    required this.pendingPlanCleanupStore,
    required this.planLeaveCoordinator,
    required this.router,
  });

  final AuthStorage storage;
  final _ContextsGateway contextsGateway;
  final AccountContextController contexts;
  final AuthController auth;
  final _ContributorAuthRepository authRepository;
  final _ControlledOfflineSyncService offline;
  final WeddingPlansProvider weddingPlans;
  final DashboardSummaryProvider dashboard;
  final _ControlledSharingApi sharing;
  final PendingPlanCleanupStore pendingPlanCleanupStore;
  final PlanLeaveCoordinator planLeaveCoordinator;
  final GoRouter router;

  static Future<_ContributorActionHarness> create({
    String initialLocation = '/workspace',
    bool withOwner = true,
    bool withArchived = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    await storage.saveSession(
      accessToken: 'session-token',
      refreshToken: 'refresh-token',
      user: const SafeUser(
        id: 'contributor-user',
        name: 'مساهم',
        phone: '+967777123456',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );

    final contributor = accountContext(
      role: AccountContextRole.contributor,
      planId: 'shared-plan',
      displayName: 'عرس المشارك',
      persona: AccountContextPersona.groom,
    );
    final archived = accountContext(
      role: AccountContextRole.contributor,
      planId: 'old-plan',
      displayName: 'عرس قديم',
      persona: AccountContextPersona.groom,
      lifecycle: 'ARCHIVED',
      isAvailable: false,
      unavailableReason: 'PLAN_ARCHIVED',
    );
    final owner = accountContext(
      role: AccountContextRole.owner,
      planId: 'owner-plan',
    );
    final contextsGateway = _ContextsGateway([
      if (withOwner) owner,
      contributor,
      if (withArchived) archived,
    ]);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'controlled contributor action test failure',
          ),
        ),
      ),
    );
    final weddingPlansApi = WeddingPlansApi(apiClient);
    final sharing = _ControlledSharingApi(apiClient);
    final pendingPlanCleanupStore = PendingPlanCleanupStore(preferences);
    final offlineDatabase = JsonLocalDatabase(preferences);
    final offline = _ControlledOfflineSyncService(
      database: offlineDatabase,
      apiClient: apiClient,
      pendingPlanCleanupStore: pendingPlanCleanupStore,
    );
    await offline.initialize();
    await offline.ensureCacheOwner('contributor-user');
    final planLeaveCoordinator = PlanLeaveCoordinator(
      sharingApi: sharing,
      offlineSync: offline,
      store: pendingPlanCleanupStore,
    );
    final contexts = AccountContextController(
      contextsApi: contextsGateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
      beforeRefresh: () =>
          planLeaveCoordinator.preparePendingForUser('contributor-user'),
      afterRefresh: () => planLeaveCoordinator
          .completeAfterContextsRefreshForUser('contributor-user'),
    );
    await contexts.refresh();
    expect(await contexts.select(contributor.contextKey), isTrue);
    final authRepository = _ContributorAuthRepository(apiClient, storage);
    final auth = AuthController(
      authRepository,
      sessionTeardownCoordinator: SessionTeardownCoordinator(
        auth: authRepository,
        clearLocalAccountData: offline.clearLocalData,
        clearGuestDraft: () async {},
      ),
    );
    await auth.restoreSession();
    final weddingPlans = WeddingPlansProvider(weddingPlansApi);
    final dashboard = DashboardSummaryProvider(
      weddingPlansApi: weddingPlansApi,
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/workspace', builder: (_, _) => const MoreScreen()),
        GoRoute(path: '/shell', builder: (_, _) => const MainShell()),
        GoRoute(
          path: '/guarded-workspace',
          builder: (_, _) => const WeddingPlanContextGate(
            weddingPlanId: 'shared-plan',
            child: MainShell(),
          ),
        ),
        GoRoute(
          path: '/shared/wedding-plans/:id',
          builder: (_, state) => ParticipantPlanStateScreen(
            weddingPlanId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: AppRouter.createWeddingPlan,
          builder: (_, _) => const SizedBox(key: Key('new-plan-destination')),
        ),
        GoRoute(
          path: AppRouter.home,
          builder: (_, _) =>
              const SizedBox(key: Key('path-choice-destination')),
        ),
        GoRoute(
          path: AppRouter.login,
          builder: (_, _) => const SizedBox(key: Key('login-destination')),
        ),
      ],
    );

    return _ContributorActionHarness(
      storage: storage,
      contextsGateway: contextsGateway,
      contexts: contexts,
      auth: auth,
      authRepository: authRepository,
      offline: offline,
      weddingPlans: weddingPlans,
      dashboard: dashboard,
      sharing: sharing,
      pendingPlanCleanupStore: pendingPlanCleanupStore,
      planLeaveCoordinator: planLeaveCoordinator,
      router: router,
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountContextController>.value(
            value: contexts,
          ),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ChangeNotifierProvider<WeddingPlansProvider>.value(
            value: weddingPlans,
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
          Provider<SharingApi>.value(value: sharing),
          Provider<PlanLeaveCoordinator>.value(value: planLeaveCoordinator),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => AarastAuthFlowRedirector(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The owner changed the participant's rights: the server's membership
  /// moves to its next authority version.
  void bumpContributorAuthority() {
    final index = contextsGateway.contexts.indexWhere(
      (context) => context.contextKey == 'plan:shared-plan:contributor',
    );
    contextsGateway.contexts[index] = accountContext(
      role: AccountContextRole.contributor,
      planId: 'shared-plan',
      displayName: 'عرس المشارك',
      persona: AccountContextPersona.groom,
      membershipAuthorityVersion: 2,
    );
  }

  void dispose() {
    router.dispose();
    dashboard.dispose();
    weddingPlans.dispose();
    auth.dispose();
    offline.dispose();
    contexts.dispose();
  }

  Future<void> seedOfflinePlanGraphs() async {
    await offline.database.saveCachedItem(
      table: OfflineTables.currentUserProfile,
      json: {
        'id': 'contributor-user',
        'name': 'مساهم',
        'role': 'USER',
        'status': 'ACTIVE',
      },
    );
    for (final planId in ['shared-plan', 'owner-plan']) {
      await offline.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: {'id': planId, 'title': planId},
      );
      final taskId = planId == 'shared-plan' ? 'shared-task' : 'owner-task';
      await offline.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: {'id': taskId, 'weddingPlanId': planId, 'title': taskId},
      );
      await offline.database.enqueueSync(
        entityType: 'task',
        operation: 'update',
        endpoint: '/api/v1/wedding-plans/$planId/tasks/$taskId',
        method: 'PATCH',
        payload: {'weddingPlanId': planId, 'title': taskId},
        planId: planId,
        localEntityId: taskId,
      );
    }
    await offline.refreshStatus();
  }
}

class _ControlledSharingApi extends SharingApi {
  // SharingApi intentionally keeps its positional client parameter private.
  // ignore: use_super_parameters
  _ControlledSharingApi(ApiClient apiClient) : super(apiClient);

  int failuresRemaining = 0;
  ApiException failure = const ApiException('controlled leave failure');
  final List<String> requestIds = [];
  final List<int> versions = [];
  Future<void> Function()? beforeLeave;

  @override
  Future<void> leaveCurrentPlan({
    required String weddingPlanId,
    required String expectedMemberId,
    required int expectedAuthorityVersion,
    required String clientRequestId,
  }) async {
    requestIds.add(clientRequestId);
    versions.add(expectedAuthorityVersion);
    await beforeLeave?.call();
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw failure;
    }
  }
}

class _ControlledOfflineSyncService extends OfflineSyncService {
  _ControlledOfflineSyncService({
    required super.database,
    required super.apiClient,
    super.pendingPlanCleanupStore,
  });

  final List<String> clearPlanCalls = [];
  Completer<void>? _planClearRelease;
  bool failNextPlanClear = false;

  void pauseNextPlanClear() {
    _planClearRelease = Completer<void>();
  }

  void releasePlanClear() {
    final release = _planClearRelease;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<void> clearPlanContext(String planId) async {
    clearPlanCalls.add(planId);
    if (failNextPlanClear) {
      failNextPlanClear = false;
      throw StateError('controlled local plan cleanup failure');
    }
    final release = _planClearRelease;
    if (release != null) await release.future;
    await super.clearPlanContext(planId);
  }
}

class _ContextsGateway implements AccountContextsGateway {
  _ContextsGateway(this.contexts);

  final List<AccountContext> contexts;
  int listCalls = 0;
  Completer<void>? _listRelease;

  void pauseNextList() {
    _listRelease = Completer<void>();
  }

  void releaseList() {
    final release = _listRelease;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<List<AccountContext>> listContexts() async {
    listCalls += 1;
    final release = _listRelease;
    if (release != null) {
      await release.future;
      if (identical(_listRelease, release)) _listRelease = null;
    }
    return contexts;
  }

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.singleWhere((context) => context.contextKey == contextKey);
  }
}

class _ContributorAuthRepository extends AuthRepository {
  _ContributorAuthRepository(super.apiClient, super.authStorage);

  static const _user = SafeUser(
    id: 'contributor-user',
    name: 'مساهم',
    phone: '+967777123456',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<String?> readAccessToken() async => 'session-token';

  @override
  Future<SafeUser> me() async => _user;

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {}
}
