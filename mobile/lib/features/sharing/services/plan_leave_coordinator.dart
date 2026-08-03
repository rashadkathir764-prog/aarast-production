import 'dart:async';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/pending_plan_cleanup.dart';
import '../data/sharing_api.dart';

class PlanLeaveCoordinator {
  PlanLeaveCoordinator({
    required SharingApi sharingApi,
    required OfflineSyncService offlineSync,
    required PendingPlanCleanupStore store,
  }) : _sharingApi = sharingApi,
       _offlineSync = offlineSync,
       _store = store;

  final SharingApi _sharingApi;
  final OfflineSyncService _offlineSync;
  final PendingPlanCleanupStore _store;
  final Set<String> _readyForContextRefresh = <String>{};
  Future<void> _operationTail = Future<void>.value();

  Future<void> leavePlan({
    required String userId,
    required String weddingPlanId,
    required String expectedMemberId,
    required int expectedAuthorityVersion,
    required String clientRequestId,
    required Future<void> Function() refreshAccountContexts,
  }) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final normalizedPlanId = _requiredId(weddingPlanId, 'weddingPlanId');
    final normalizedRequestId = _requiredId(clientRequestId, 'clientRequestId');
    await _serialize(() async {
      // The durable write is deliberately before quiescing or contacting the
      // server. A process death after this await can replay the exact request.
      final durableRecord = await _store.putIfAbsent(
        userId: normalizedUserId,
        planId: normalizedPlanId,
        expectedMemberId: _requiredId(expectedMemberId, 'expectedMemberId'),
        expectedAuthorityVersion: expectedAuthorityVersion,
        clientRequestId: normalizedRequestId,
      );
      await _execute(durableRecord);
    });
    // Run outside the coordinator's serialization tail: refresh invokes the
    // replay hooks on this same coordinator and would otherwise deadlock.
    // The callback itself was captured from the app-scoped controller before
    // the screen could unmount, so invalidation never depends on BuildContext.
    await refreshAccountContexts();
  }

  /// Replays every unresolved leave before account contexts are loaded.
  ///
  /// The returned plan ids must be filtered from the live contexts response.
  /// A network-ambiguous request or a failed local cleanup remains hidden and
  /// durable; a definitive 4xx is removed and may appear again from the API.
  Future<Set<String>> preparePendingForUser(String userId) {
    final normalizedUserId = _requiredId(userId, 'userId');
    return _serialize(() async {
      final records = await _store.readAll();
      for (final record in records) {
        if (record.userId != normalizedUserId) continue;
        if (_readyForContextRefresh.contains(record.identity)) continue;
        try {
          await _execute(record);
        } on ApiException catch (error) {
          // _execute only rethrows a definitive server rejection after it has
          // removed the marker. Startup refresh must continue so the server's
          // still-valid context can be shown again.
          appLogEvent(
            'PLAN_LEAVE_REPLAY_REJECTED',
            category: AppLogCategory.session,
            level: AppLogLevel.warning,
            userId: record.userId,
            weddingPlanId: record.planId,
            source: 'PlanLeaveCoordinator.preparePendingForUser',
            reason: error.serverCode ?? 'definitive_server_rejection',
            attributes: {'statusCode': error.statusCode ?? 0},
          );
        }
      }
      return _store.planIdsForUser(normalizedUserId);
    });
  }

  /// Removes only markers whose remote leave and local plan-graph deletion
  /// both completed, and only after AccountContextController committed a fresh
  /// filtered context list.
  Future<void> completeAfterContextsRefreshForUser(String userId) {
    final normalizedUserId = _requiredId(userId, 'userId');
    return _serialize(() async {
      final records = await _store.readAll();
      for (final record in records) {
        if (record.userId != normalizedUserId ||
            !_readyForContextRefresh.contains(record.identity)) {
          continue;
        }
        try {
          await _store.remove(record);
        } on Object catch (error) {
          appLogEvent(
            'PLAN_LEAVE_MARKER_CLEAR_FAILED',
            category: AppLogCategory.session,
            level: AppLogLevel.warning,
            userId: record.userId,
            weddingPlanId: record.planId,
            source: 'PlanLeaveCoordinator.completeAfterContextsRefreshForUser',
            reason: 'durable_store_write_failed',
            attributes: {'errorType': error.runtimeType.toString()},
          );
          continue;
        }
        _readyForContextRefresh.remove(record.identity);
        _offlineSync.releasePlanQuarantine(record.planId);
        appLogEvent(
          'PLAN_LEAVE_CLEANUP_COMPLETED',
          category: AppLogCategory.session,
          userId: record.userId,
          weddingPlanId: record.planId,
          source: 'PlanLeaveCoordinator',
        );
      }
    });
  }

  Future<void> _execute(PendingPlanCleanupRecord record) async {
    appLogEvent(
      'PLAN_LEAVE_CLEANUP_STARTED',
      category: AppLogCategory.session,
      userId: record.userId,
      weddingPlanId: record.planId,
      source: 'PlanLeaveCoordinator',
    );
    try {
      await _offlineSync.quiescePlan(record.planId);
    } on Object catch (error) {
      _logPending(record, 'offline_quiesce_failed', error);
      return;
    }
    try {
      await _sharingApi.leaveCurrentPlan(
        weddingPlanId: record.planId,
        expectedMemberId: record.expectedMemberId,
        expectedAuthorityVersion: record.expectedAuthorityVersion,
        clientRequestId: record.clientRequestId,
      );
    } on ApiException catch (error) {
      if (!error.isAmbiguousMutationFailure) {
        await _store.remove(record);
        _readyForContextRefresh.remove(record.identity);
        _offlineSync.releasePlanQuarantine(record.planId);
        appLogEvent(
          'PLAN_LEAVE_REJECTED',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: record.userId,
          weddingPlanId: record.planId,
          source: 'PlanLeaveCoordinator',
          reason: error.serverCode ?? 'definitive_server_rejection',
          attributes: {'statusCode': error.statusCode ?? 0},
        );
        rethrow;
      }
      _logPending(record, 'ambiguous_remote_result', error);
      return;
    } on Object catch (error) {
      // A non-API transport/runtime failure does not prove that the DELETE
      // stayed client-side. Keep the marker and fail closed.
      _logPending(record, 'unclassified_remote_result', error);
      return;
    }

    try {
      await _offlineSync.clearPlanContext(record.planId);
    } on Object catch (error) {
      _logPending(record, 'local_plan_cleanup_failed', error);
      return;
    }
    _readyForContextRefresh.add(record.identity);
    appLogEvent(
      'PLAN_LEAVE_AWAITING_CONTEXT_REFRESH',
      category: AppLogCategory.session,
      userId: record.userId,
      weddingPlanId: record.planId,
      source: 'PlanLeaveCoordinator',
    );
  }

  void _logPending(
    PendingPlanCleanupRecord record,
    String reason,
    Object error,
  ) {
    appLogEvent(
      'PLAN_LEAVE_CLEANUP_PENDING',
      category: AppLogCategory.session,
      level: AppLogLevel.warning,
      userId: record.userId,
      weddingPlanId: record.planId,
      source: 'PlanLeaveCoordinator',
      reason: reason,
      attributes: {'errorType': error.runtimeType.toString()},
    );
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    Future<void> run() async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _operationTail = _operationTail.then<void>(
      (_) => run(),
      onError: (_, _) => run(),
    );
    return completer.future;
  }
}

String _requiredId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}
