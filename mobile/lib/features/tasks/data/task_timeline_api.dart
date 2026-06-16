import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineApi {
  const TaskTimelineApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/tasks',
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
    final key = 'timeline:$weddingPlanId';
    try {
      final json = await _apiClient.getJson(
        '/wedding-plans/$weddingPlanId/timeline',
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

  Future<WeddingTask> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String status = 'TODO',
    String priority = 'MEDIUM',
  }) async {
    final payload = {
      'title': title.trim(),
      'status': status,
      'priority': priority,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (taskCategory != null && taskCategory.trim().isNotEmpty)
        'taskCategory': taskCategory.trim(),
    };
    try {
      final json = await _apiClient.postJson(
        '/wedding-plans/$weddingPlanId/tasks',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedTasks,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return WeddingTask.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-task-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        ...payload,
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
        endpoint: '/wedding-plans/$weddingPlanId/tasks',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return WeddingTask.fromJson(localJson);
    }
  }

  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    try {
      final json = await _apiClient.patchJson('/tasks/$id', data);
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
        endpoint: '/tasks/$id',
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
      await _apiClient.deleteJson('/tasks/$id');
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
        endpoint: '/tasks/$id',
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
      'dueDebts': const [],
      'dueInstallments': const [],
    });
  }
}
