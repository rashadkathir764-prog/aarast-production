import '../../../core/network/api_client.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineApi {
  const TaskTimelineApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/tasks',
    );
    return list
        .whereType<Map>()
        .map((item) => WeddingTask.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Timeline> getTimeline(String weddingPlanId) async {
    final json = await _apiClient.getJson(
      '/wedding-plans/$weddingPlanId/timeline',
    );
    return Timeline.fromJson(json);
  }

  Future<WeddingTask> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String status = 'TODO',
    String priority = 'MEDIUM',
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/tasks', {
          'title': title.trim(),
          'status': status,
          'priority': priority,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        });
    return WeddingTask.fromJson(json);
  }

  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    final json = await _apiClient.patchJson('/tasks/$id', data);
    return WeddingTask.fromJson(json);
  }

  Future<void> deleteTask(String id) async {
    await _apiClient.deleteJson('/tasks/$id');
  }
}
