import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/task_summary.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineApi {
  const TaskTimelineApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

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
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'status': status,
      'priority': priority,
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
        localEntityId: localId,
      );
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

    final json = await _apiClient.patchJson(
      '/api/v1/tasks/$id/assign',
      payload,
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
      await _offline.database.enqueueSync(
        entityType: 'task',
        operation: 'update',
        endpoint: '/api/v1/tasks/$id',
        method: 'PATCH',
        payload: data,
        localEntityId: id,
      );
      await _offline.refreshStatus();
      return WeddingTask.fromJson(localJson);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _apiClient.deleteJson('/api/v1/tasks/$id');
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedTasks,
        id: id,
      );
      if (cached != null) {
        await _offline.database.saveCachedItem(
          table: OfflineTables.cachedTasks,
          json: cached,
          dirty: true,
          deletedLocally: true,
        );
      }
      await _offline.database.enqueueSync(
        entityType: 'task',
        operation: 'delete',
        endpoint: '/api/v1/tasks/$id',
        method: 'DELETE',
        payload: const {},
        localEntityId: id,
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
    return cached.isEmpty ? null : cached;
  }

  Future<Timeline> _timelineFromCachedTasks(String weddingPlanId) async {
    final tasks = await _offline?.database.readCachedList(
      table: OfflineTables.cachedTasks,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    if (tasks == null || tasks.isEmpty) return Timeline.empty();
    final upcoming = tasks
        .where((task) => task['status'] != 'DONE' && task['dueDate'] != null)
        .take(5)
        .toList();
    return Timeline.fromJson({
      'upcomingTasks': upcoming,
      'dueCommitments': const [],
      'dueInstallments': const [],
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
        'responsibleName': responsibleName!.trim(),
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
    };
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
