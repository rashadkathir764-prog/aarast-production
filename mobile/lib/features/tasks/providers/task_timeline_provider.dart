import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../data/task_timeline_api.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineProvider extends ChangeNotifier {
  TaskTimelineProvider(this._api);

  final TaskTimelineApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<WeddingTask> _tasks = const [];
  Timeline _timeline = Timeline.empty();

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<WeddingTask> get tasks => _tasks;
  Timeline get timeline => _timeline;

  Future<void> load(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Object? loadError;

    Future<List<WeddingTask>?> loadTasks() async {
      try {
        return await _api.getTasks(weddingPlanId);
      } catch (error) {
        loadError ??= error;
        return null;
      }
    }

    Future<Timeline?> loadTimeline() async {
      try {
        return await _api.getTimeline(weddingPlanId);
      } catch (error) {
        loadError ??= error;
        return null;
      }
    }

    try {
      final results = await Future.wait<Object?>([loadTasks(), loadTimeline()]);
      final tasks = results[0] as List<WeddingTask>?;
      final timeline = results[1] as Timeline?;

      if (tasks != null) {
        _tasks = tasks;
      } else {
        _tasks = _tasks
            .where((task) => task.weddingPlanId == weddingPlanId)
            .toList();
      }

      _timeline = timeline ?? Timeline.empty();

      if (loadError != null) {
        _errorMessage = _loadErrorMessage(loadError!);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل المهام والجدول الزمني.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _loadErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù…Ù‡Ø§Ù… ÙˆØ§Ù„Ø¬Ø¯ÙˆÙ„ Ø§Ù„Ø²Ù…Ù†ÙŠ.';
  }

  Future<bool> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String status = 'TODO',
    String priority = 'MEDIUM',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final task = await _api.createTask(
        weddingPlanId: weddingPlanId,
        title: title,
        description: description,
        dueDate: dueDate,
        status: status,
        priority: priority,
      );
      _tasks = [task, ..._tasks.where((item) => item.id != task.id)];
      if (task.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
        _timeline = await _api.getTimeline(weddingPlanId);
      } else {
        _timeline = await _api.getTimeline(weddingPlanId);
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء المهمة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> markTaskDone(String weddingPlanId, WeddingTask task) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateTask(task.id, {'status': 'DONE'});
      _tasks = [
        for (final item in _tasks) item.id == updated.id ? updated : item,
      ];
      if (updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      _timeline = await _api.getTimeline(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث المهمة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTask(String weddingPlanId, String taskId) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.deleteTask(taskId);
      _tasks = _tasks.where((item) => item.id != taskId).toList();
      _timeline = await _api.getTimeline(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف المهمة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }
}
