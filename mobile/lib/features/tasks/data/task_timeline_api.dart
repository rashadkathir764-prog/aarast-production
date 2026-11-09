import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/utils/text_limits.dart';
import '../models/task_checklist_item.dart';
import '../models/task_summary.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineApi {
  TaskTimelineApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline,
      _writes = OfflineWrites(_apiClient, offline);

  final OfflineWrites _writes;

  /// D89: the sub-steps, the assignment and the bulk date shift are the
  /// server's to keep (their ids and members live there); the task itself
  /// stays on the phone (D85).
  static const _stepsNeedServer =
      'الخطوات الفرعية تُحفظ في الخادم الحين؛ المهمة نفسها محفوظة في جوالك.';
  static const _assignNeedsServer =
      'تعيين المسؤول يتأكد من عضويته في الخطة، فيحتاج الخادم.';

  /// RA-BE-15: the server's TASK_PERSON_NAME_MAX. A name picked from the
  /// contacts is set from code and can pass the field's limit.
  static const _personNameMax = 120;

  static int _localTaskSequence = 0;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(WeddingTask.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$weddingPlanId/tasks',
      );
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedTasks,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(WeddingTask.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) return cached.map(WeddingTask.fromJson).toList();
      rethrow;
    }
  }

  /// D85: the phone's copy alone, shown before the server is asked.
  Future<List<WeddingTask>> cachedTasks(String weddingPlanId) async {
    final cached = await _offline?.database.readCachedList(
      table: OfflineTables.cachedTasks,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return (cached ?? const <Map<String, dynamic>>[])
        .map(WeddingTask.fromJson)
        .toList();
  }

  Future<Timeline?> cachedTimeline(String weddingPlanId) async {
    final raw = await _offline?.database.getMeta('timeline:$weddingPlanId');
    if (raw == null) return null;
    try {
      return Timeline.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  Future<TaskSummary?> cachedTaskSummary(String weddingPlanId) async {
    final raw = await _offline?.database.getMeta('task-summary:$weddingPlanId');
    if (raw == null) return null;
    try {
      return TaskSummary.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  Future<Timeline> getTimeline(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _timelineFromCachedTasks(weddingPlanId);
    }
    final key = 'timeline:$weddingPlanId';
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$weddingPlanId/timeline',
      );
      await _offline?.database.setMeta(key, jsonEncode(json));
      return Timeline.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      OfflineReads.noteCopyServed();
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached != null) {
        return Timeline.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
      return _timelineFromCachedTasks(weddingPlanId);
    }
  }

  Future<TaskSummary> getTaskSummary(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _taskSummaryFromCachedTasks(weddingPlanId);
    }
    final key = 'task-summary:$weddingPlanId';
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$weddingPlanId/tasks/summary',
      );
      await _offline?.database.setMeta(key, jsonEncode(json));
      return TaskSummary.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      OfflineReads.noteCopyServed();
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached != null) {
        return TaskSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
      return _taskSummaryFromCachedTasks(weddingPlanId);
    }
  }

  Future<WeddingTask> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
    String status = 'TODO',
    String priority = 'MEDIUM',
    bool isPrivate = false,
    String? starterKey,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'status': status,
      'priority': priority,
      // V1 checklist 4.10: kept to its account (also when queued offline).
      if (isPrivate) 'isPrivate': true,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (taskCategory != null && taskCategory.trim().isNotEmpty)
        'taskCategory': taskCategory.trim(),
    };
    final localResponsibility = _responsibilityPayload(
      assigneeUserId: assigneeUserId,
      assigneeName: assigneeName,
      assigneePhone: assigneePhone,
      assigneeRole: assigneeRole,
      responsibleName: responsibleName,
      responsiblePhone: responsiblePhone,
      responsibleSource: responsibleSource,
    );
    if (!_hasValue(assigneeUserId)) {
      payload.addAll(localResponsibility);
    }
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalTask(
        weddingPlanId: weddingPlanId,
        payload: {...payload, ...localResponsibility},
      );
    }
    // A plan on the phone has no items yet; imported tasks stay unlinked.
    if (starterKey != null) payload['starterKey'] = starterKey;
    try {
      final json = await _apiClient.postJson(
        '/api/v1/wedding-plans/$weddingPlanId/tasks',
        payload,
      );
      var taskJson = Map<String, dynamic>.from(json);
      if (_hasValue(assigneeUserId)) {
        final assigned = await assignTask(
          json['id'].toString(),
          assigneeUserId: assigneeUserId,
          assigneeName: assigneeName,
          assigneePhone: assigneePhone,
          assigneeRole: assigneeRole,
        );
        taskJson = _taskToCacheJson(assigned);
      }
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: taskJson,
      );
      await _offline?.syncPendingChanges();
      return WeddingTask.fromJson(taskJson);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = _nextLocalTaskId(now);
      final localJson = {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        ...payload,
        ...localResponsibility,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'task',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/$weddingPlanId/tasks',
        method: 'POST',
        payload: payload,
        planId: weddingPlanId,
        localEntityId: localId,
      );
      if (_hasValue(assigneeUserId)) {
        await _offline.database.enqueueSync(
          entityType: 'task',
          operation: 'assign',
          endpoint: '/api/v1/tasks/$localId/assign',
          method: 'PATCH',
          payload: {'assigneeUserId': assigneeUserId!.trim()},
          planId: weddingPlanId,
          localEntityId: localId,
          replacePendingForEntity: true,
        );
      }
      await _offline.refreshStatus();
      return WeddingTask.fromJson(localJson);
    }
  }

  Future<WeddingTask> assignTask(
    String id, {
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
  }) async {
    final payload = {'assigneeUserId': _trimmedOrNull(assigneeUserId)};
    final localData = {
      ...payload,
      if (_hasValue(assigneeName)) 'assigneeName': assigneeName!.trim(),
      if (_hasValue(assigneePhone)) 'assigneePhone': assigneePhone!.trim(),
      if (_hasValue(assigneeRole)) 'assigneeRole': assigneeRole!.trim(),
      'responsibleName': null,
      'responsiblePhone': null,
      'responsibleSource': null,
    };
    if (id.startsWith('local-task-')) {
      return _updateLocalTask(id: id, data: localData);
    }

    final json = await _writes.serverOnly(
      reason: _assignNeedsServer,
      method: 'PATCH',
      path: '/api/v1/tasks/$id/assign',
      body: payload,
    );
    final hydratedJson = {
      ...Map<String, dynamic>.from(json),
      if (_hasValue(assigneeName)) 'assigneeName': assigneeName!.trim(),
      if (_hasValue(assigneePhone)) 'assigneePhone': assigneePhone!.trim(),
      if (_hasValue(assigneeRole)) 'assigneeRole': assigneeRole!.trim(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: hydratedJson,
    );
    await _offline?.syncPendingChanges();
    return WeddingTask.fromJson(hydratedJson);
  }

  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    if (id.startsWith('local-task-')) {
      return _updateLocalTask(id: id, data: data);
    }
    try {
      final json = await _apiClient.patchJson('/api/v1/tasks/$id', data);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return WeddingTask.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: id,
      );
      if (cached == null) rethrow;
      final localJson = {
        ...cached,
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: localJson,
        dirty: true,
      );
      await _queueTaskEdit(
        id: id,
        operation: 'update',
        endpoint: '/api/v1/tasks/$id',
        payload: await _mergedQueuedTaskPayload(
          id: id,
          operation: 'update',
          data: data,
        ),
        planId: _taskPlanId(localJson),
      );
      await _offline.refreshStatus();
      return WeddingTask.fromJson(localJson);
    }
  }

  Future<void> deleteTask(String id) async {
    final offline = _offline;
    if (id.startsWith('local-task-') && offline != null) {
      // RA-MO-30: dropped on the phone only while its create was never
      // sent; otherwise the server may have it, and a delete goes after it.
      if (!await offline.database.discardUnsentLocalEntity(
        table: OfflineTables.cachedTasks,
        entityType: 'task',
        entityId: id,
      )) {
        final cached = await offline.database.readCachedItem(
          table: OfflineTables.cachedTasks,
          id: id,
        );
        if (cached != null) {
          await offline.database.saveCachedItem(
            table: OfflineTables.cachedTasks,
            json: cached,
            dirty: true,
            deletedLocally: true,
          );
        }
        await offline.database.enqueueSync(
          entityType: 'task',
          operation: 'delete',
          endpoint: '/api/v1/tasks/$id',
          method: 'DELETE',
          payload: const {},
          planId: cached == null ? null : _taskPlanId(cached),
          localEntityId: id,
          replacePendingForEntity: true,
        );
      }
      await offline.refreshStatus();
      return;
    }
    if (id.startsWith('local-task-')) return;
    try {
      await _apiClient.deleteJson('/api/v1/tasks/$id');
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: id,
      );
      if (cached == null) rethrow;
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: cached,
        dirty: true,
        deletedLocally: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'task',
        operation: 'delete',
        endpoint: '/api/v1/tasks/$id',
        method: 'DELETE',
        payload: const {},
        planId: _taskPlanId(cached),
        localEntityId: id,
        replaceAllPendingForEntity: true,
      );
      await _offline.refreshStatus();
    }
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    if (cached.isEmpty) return null;
    OfflineReads.noteCopyServed();
    return cached;
  }

  Future<Timeline> _timelineFromCachedTasks(String weddingPlanId) async {
    final database = _offline?.database;
    if (database == null) return Timeline.empty();
    final results = await Future.wait([
      database.readCachedList(
        table: OfflineTables.cachedTasks,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      ),
      database.readCachedList(
        table: OfflineTables.cachedPaymentSchedules,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      ),
      database.readCachedList(
        table: OfflineTables.cachedCosts,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      ),
    ]);
    final tasks = results[0];
    final schedules = results[1];
    final costs = results[2];
    final costTitleById = {
      for (final cost in costs)
        if (cost['id'] != null)
          cost['id'].toString(): cost['title']?.toString() ?? '',
    };
    final upcoming = tasks
        .where((task) => task['status'] != 'DONE' && task['dueDate'] != null)
        .take(5)
        .toList();
    final paymentSchedules =
        schedules
            .where(
              (schedule) =>
                  schedule['status'] == 'PENDING' &&
                  schedule['dueDate'] != null,
            )
            .map((schedule) {
              final costId =
                  schedule['weddingCostId']?.toString() ??
                  schedule['costId']?.toString() ??
                  '';
              return {
                ...schedule,
                'weddingCostId': costId,
                'costTitle':
                    schedule['costTitle']?.toString() ??
                    costTitleById[costId] ??
                    '',
              };
            })
            .toList()
          ..sort(
            (left, right) => DateTime.parse(
              left['dueDate'].toString(),
            ).compareTo(DateTime.parse(right['dueDate'].toString())),
          );
    return Timeline.fromJson({
      'upcomingTasks': upcoming,
      'paymentSchedules': paymentSchedules,
    });
  }

  Future<TaskSummary> _taskSummaryFromCachedTasks(String weddingPlanId) async {
    final tasks = await _offline?.database.readCachedList(
      table: OfflineTables.cachedTasks,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return TaskSummary.fromTasks(
      weddingPlanId: weddingPlanId,
      tasks: (tasks ?? const <Map<String, dynamic>>[])
          .map(WeddingTask.fromJson)
          .toList(),
    );
  }

  Future<WeddingTask> _createLocalTask({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localId = _nextLocalTaskId(now);
    final localJson = {
      'id': localId,
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return WeddingTask.fromJson(localJson);
  }

  Future<void> _coalesceLocalTaskWrites({
    required String id,
    required Map<String, dynamic> localJson,
    required Map<String, dynamic> data,
  }) async {
    final database = _offline?.database;
    if (database == null) return;
    final create = await _queuedTaskItem(id, 'create');
    if (create == null) return;
    final planId = _taskPlanId(localJson);
    final isAssignment = data.containsKey('assigneeUserId');
    // RA-MO-30: the create carries the edit only while it was never sent.
    // Once sent, the server may have it, and the same request id with
    // another body is a 409: the edit goes after it as its own.
    final createRewritten = await database.rewriteUnsentSyncItem(
      entityType: 'task',
      operation: 'create',
      localEntityId: id,
      planId: planId,
      endpoint: create.endpoint,
      payload: _taskCreatePayloadFromLocal(localJson),
    );
    if (!createRewritten && !isAssignment) {
      await _queueTaskEdit(
        id: id,
        operation: 'update',
        endpoint: '/api/v1/tasks/$id',
        payload: await _mergedQueuedTaskPayload(
          id: id,
          operation: 'update',
          data: data,
        ),
        planId: planId,
      );
    }

    if (isAssignment) {
      await _queueTaskEdit(
        id: id,
        operation: 'assign',
        endpoint: '/api/v1/tasks/$id/assign',
        payload: {
          'assigneeUserId': _trimmedOrNull(data['assigneeUserId']?.toString()),
        },
        planId: planId,
      );
    }
  }

  /// RA-MO-30: an edit of a task rewrites its waiting edit in place (same
  /// request id and place) while that was never sent; otherwise it is a new
  /// change with a new request id, carrying the waiting fields: the waiting
  /// one may be on the server already, and an edit applies twice safely.
  Future<void> _queueTaskEdit({
    required String id,
    required String operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String? planId,
  }) async {
    final database = _offline?.database;
    if (database == null) return;
    if (await database.rewriteUnsentSyncItem(
      entityType: 'task',
      operation: operation,
      localEntityId: id,
      planId: planId,
      endpoint: endpoint,
      payload: payload,
    )) {
      return;
    }
    await database.enqueueSync(
      entityType: 'task',
      operation: operation,
      endpoint: endpoint,
      method: 'PATCH',
      payload: payload,
      planId: planId,
      localEntityId: id,
      replacePendingForEntity: true,
    );
  }

  Future<Map<String, dynamic>> _mergedQueuedTaskPayload({
    required String id,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final items = await _queuedTaskItems(id, operation);
    return {for (final item in items) ...item.payload, ...data};
  }

  Future<SyncQueueItem?> _queuedTaskItem(String id, String operation) async {
    final items = await _queuedTaskItems(id, operation);
    return items.isEmpty ? null : items.first;
  }

  Future<List<SyncQueueItem>> _queuedTaskItems(
    String id,
    String operation,
  ) async {
    final database = _offline?.database;
    if (database == null) return const [];
    final items = [
      ...await database.pendingSyncItems(),
      ...await database.blockedSyncItems(),
    ];
    return items
        .where(
          (item) =>
              item.entityType == 'task' &&
              item.localEntityId == id &&
              item.operation == operation,
        )
        .toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  }

  Map<String, dynamic> _taskCreatePayloadFromLocal(
    Map<String, dynamic> localJson,
  ) {
    return {
      'title': localJson['title']?.toString().trim() ?? '',
      'status': localJson['status']?.toString() ?? 'TODO',
      'priority': localJson['priority']?.toString() ?? 'MEDIUM',
      if (_hasValue(localJson['description']?.toString()))
        'description': localJson['description'].toString().trim(),
      if (localJson['dueDate'] != null)
        'dueDate': localJson['dueDate'].toString(),
      if (_hasValue(localJson['taskCategory']?.toString()))
        'taskCategory': localJson['taskCategory'].toString().trim(),
      if (_hasValue(localJson['responsibleName']?.toString()))
        'responsibleName': clipToCharacters(
          localJson['responsibleName'].toString().trim(),
          _personNameMax,
        ),
      if (_hasValue(localJson['responsiblePhone']?.toString()))
        'responsiblePhone': localJson['responsiblePhone'].toString().trim(),
      if (_hasValue(localJson['responsibleSource']?.toString()))
        'responsibleSource': localJson['responsibleSource'].toString().trim(),
    };
  }

  Future<WeddingTask> _updateLocalTask({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedTasks,
      id: id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...data,
      'id': id,
      'weddingPlanId': cached?['weddingPlanId'] ?? '',
      'createdAt': cached?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: localJson,
      dirty: true,
    );
    await _coalesceLocalTaskWrites(id: id, localJson: localJson, data: data);
    await _offline?.refreshStatus();
    return WeddingTask.fromJson(localJson);
  }

  bool _isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }

  static String _nextLocalTaskId(DateTime now) {
    _localTaskSequence += 1;
    return 'local-task-${now.microsecondsSinceEpoch}-$_localTaskSequence';
  }

  Map<String, dynamic> _responsibilityPayload({
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
  }) {
    if (_hasValue(assigneeUserId)) {
      return {
        'assigneeUserId': assigneeUserId!.trim(),
        if (_hasValue(assigneeName)) 'assigneeName': assigneeName!.trim(),
        if (_hasValue(assigneePhone)) 'assigneePhone': assigneePhone!.trim(),
        if (_hasValue(assigneeRole)) 'assigneeRole': assigneeRole!.trim(),
      };
    }

    return {
      if (_hasValue(responsibleName))
        'responsibleName': clipToCharacters(
          responsibleName!.trim(),
          _personNameMax,
        ),
      if (_hasValue(responsiblePhone))
        'responsiblePhone': responsiblePhone!.trim(),
      if (_hasValue(responsibleSource))
        'responsibleSource': responsibleSource!.trim(),
    };
  }

  Map<String, dynamic> _taskToCacheJson(WeddingTask task) {
    return {
      'id': task.id,
      'weddingPlanId': task.weddingPlanId,
      'title': task.title,
      'status': task.status,
      'priority': task.priority,
      if (task.description != null) 'description': task.description,
      if (task.dueDate != null) 'dueDate': task.dueDate!.toIso8601String(),
      if (task.taskCategory != null) 'taskCategory': task.taskCategory,
      if (task.assigneeUserId != null) 'assigneeUserId': task.assigneeUserId,
      if (task.assigneeName != null) 'assigneeName': task.assigneeName,
      if (task.assigneePhone != null) 'assigneePhone': task.assigneePhone,
      if (task.assigneeRole != null) 'assigneeRole': task.assigneeRole,
      if (task.responsibleName != null) 'responsibleName': task.responsibleName,
      if (task.responsiblePhone != null)
        'responsiblePhone': task.responsiblePhone,
      if (task.responsibleSource != null)
        'responsibleSource': task.responsibleSource,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'checklist': [for (final item in task.checklist) item.toJson()],
      if (task.isPrivate) 'isPrivate': true,
      if (task.linkedBudgetCategoryId != null)
        'linkedBudgetCategoryId': task.linkedBudgetCategoryId,
      if (task.linkedCostId != null) 'linkedCostId': task.linkedCostId,
      if (task.linkedScheduleId != null)
        'linkedScheduleId': task.linkedScheduleId,
      if (task.autoClosedAt != null)
        'autoClosedAt': task.autoClosedAt!.toIso8601String(),
    };
  }

  /// Checklist steps are saved on the server only, so they need a connection
  /// and a task that already exists there (not a device-only task).
  Future<TaskChecklistItem> createChecklistItem(
    WeddingTask task,
    String title,
  ) async {
    _assertChecklistAvailable(task);
    final json = await _writes.serverOnly(
      reason: _stepsNeedServer,
      method: 'POST',
      path: '/api/v1/tasks/${task.id}/checklist',
      body: {'title': title.trim(), 'sortOrder': task.checklist.length},
    );
    final item = TaskChecklistItem.fromJson(json);
    await _cacheChecklist(task, [...task.checklist, item]);
    return item;
  }

  Future<TaskChecklistItem> updateChecklistItem(
    WeddingTask task,
    TaskChecklistItem item, {
    String? title,
    bool? isDone,
  }) async {
    _assertChecklistAvailable(task);
    final json = await _writes.serverOnly(
      reason: _stepsNeedServer,
      method: 'PATCH',
      path: '/api/v1/tasks/${task.id}/checklist/${item.id}',
      body: {'title': ?title?.trim(), 'isDone': ?isDone},
    );
    final updated = TaskChecklistItem.fromJson(json);
    await _cacheChecklist(task, [
      for (final current in task.checklist)
        current.id == updated.id ? updated : current,
    ]);
    return updated;
  }

  Future<void> deleteChecklistItem(
    WeddingTask task,
    TaskChecklistItem item,
  ) async {
    _assertChecklistAvailable(task);
    await _writes.serverOnly(
      reason: _stepsNeedServer,
      method: 'DELETE',
      path: '/api/v1/tasks/${task.id}/checklist/${item.id}',
    );
    await _cacheChecklist(task, [
      for (final current in task.checklist)
        if (current.id != item.id) current,
    ]);
  }

  void _assertChecklistAvailable(WeddingTask task) {
    if (task.id.startsWith('local-') ||
        _isLocalGuestPlanId(task.weddingPlanId)) {
      throw const ApiException(
        'القائمة الفرعية تُحفظ في حسابك؛ احفظ المهمة على حسابك أولًا.',
      );
    }
  }

  Future<void> _cacheChecklist(
    WeddingTask task,
    List<TaskChecklistItem> checklist,
  ) async {
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: _taskToCacheJson(task.copyWith(checklist: checklist)),
    );
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _taskPlanId(Map<String, dynamic> json) {
    final planId = json['weddingPlanId']?.toString().trim();
    if (planId == null || planId.isEmpty) {
      throw const FormatException('Task cache row is missing weddingPlanId');
    }
    return planId;
  }
}
