import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/task_timeline_api.dart';
import '../models/task_checklist_item.dart';
import '../models/task_starter_catalog.dart';
import '../models/task_summary.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';

class TaskTimelineProvider extends ChangeNotifier with SessionScopedNotifier {
  TaskTimelineProvider(this._api);

  final TaskTimelineApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<WeddingTask> _tasks = const [];
  Timeline _timeline = Timeline.empty();
  TaskSummary _summary = TaskSummary.empty('');
  final Map<String, int> _statusMutationVersions = {};
  final Map<String, String> _lastMeaningfulStatuses = {};
  bool _isSavingChecklist = false;
  String? _checklistErrorMessage;

  bool get isSavingChecklist => _isSavingChecklist;
  String? get checklistErrorMessage => _checklistErrorMessage;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<WeddingTask> get tasks => _tasks;
  Timeline get timeline => _timeline;
  TaskSummary get summary => _summary;

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

    Future<TaskSummary?> loadSummary() async {
      try {
        return await _api.getTaskSummary(weddingPlanId);
      } catch (error) {
        loadError ??= error;
        return null;
      }
    }

    try {
      final results = await Future.wait<Object?>([
        loadTasks(),
        loadTimeline(),
        loadSummary(),
      ]);
      final tasks = results[0] as List<WeddingTask>?;
      final timeline = results[1] as Timeline?;
      final summary = results[2] as TaskSummary?;

      if (tasks != null) {
        _tasks = tasks;
      } else {
        _tasks = _tasks
            .where((task) => task.weddingPlanId == weddingPlanId)
            .toList();
      }

      _timeline = timeline ?? Timeline.empty();
      _summary =
          summary ??
          TaskSummary.fromTasks(weddingPlanId: weddingPlanId, tasks: _tasks);

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
    return 'تعذر تحميل المهام.';
  }

  Future<bool> createTask({
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
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final task = await _api.createTask(
        isPrivate: isPrivate,
        weddingPlanId: weddingPlanId,
        title: title,
        description: description,
        dueDate: dueDate,
        taskCategory: _taskCategoryForPayload(taskCategory),
        assigneeUserId: assigneeUserId,
        assigneeName: assigneeName,
        assigneePhone: assigneePhone,
        assigneeRole: assigneeRole,
        responsibleName: responsibleName,
        responsiblePhone: responsiblePhone,
        responsibleSource: responsibleSource,
        status: status,
        priority: priority,
      );
      _tasks = [task, ..._tasks.where((item) => item.id != task.id)];
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
        await _refreshTaskData(weddingPlanId);
      } else if (task.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
        await _refreshTaskData(weddingPlanId);
      } else {
        await _refreshTaskData(weddingPlanId);
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

  /// Adds the chosen suggested tasks. A template whose title the plan
  /// already has is skipped, so adding twice never duplicates. Returns how
  /// many were added; a partial failure keeps what was saved and says so.
  Future<int> addStarterTasks({
    required String weddingPlanId,
    required List<TaskStarterTemplate> templates,
    required DateTime? weddingDate,
    DateTime? today,
  }) async {
    final existing = {
      for (final task in _tasks)
        if (task.weddingPlanId == weddingPlanId)
          taskStarterTitleKey(task.title),
    };
    final pending = templates
        .where((item) => existing.add(taskStarterTitleKey(item.title)))
        .toList(growable: false);
    if (pending.isEmpty) {
      _noticeMessage = 'كل المهام المختارة موجودة في خطتك بالفعل.';
      notifyListeners();
      return 0;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    final now = today ?? DateTime.now();
    final longestDaysBefore = pending
        .map((item) => item.daysBefore ?? 0)
        .fold(0, (longest, value) => value > longest ? value : longest);
    var added = 0;
    var queuedOffline = false;
    String? failure;
    try {
      for (final template in pending) {
        try {
          final task = await _api.createTask(
            weddingPlanId: weddingPlanId,
            title: template.title,
            taskCategory: template.taskCategory,
            dueDate: taskStarterDueDate(
              weddingDate,
              template.daysBefore,
              now,
              longestDaysBefore: longestDaysBefore,
            ),
          );
          added += 1;
          queuedOffline = queuedOffline || task.id.startsWith('local-');
          _tasks = [task, ..._tasks.where((item) => item.id != task.id)];
        } on ApiException catch (error) {
          failure = error.message;
          break;
        } catch (_) {
          failure = 'تعذر حفظ المهمة.';
          break;
        }
      }
      if (added > 0) await _refreshTaskData(weddingPlanId);
    } finally {
      if (failure != null) {
        _errorMessage = added == 0
            ? failure
            : 'أُضيفت $added من ${pending.length} مهام، وتعذر حفظ الباقي: $failure';
      } else if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (queuedOffline) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      _isSubmitting = false;
      notifyListeners();
    }
    return added;
  }

  /// V1 checklist 4.10: shows a private task to the whole plan. A shared
  /// task never becomes private again.
  Future<bool> shareTaskWithPlan(String weddingPlanId, WeddingTask task) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final updated = await _api.updateTask(task.id, {'isPrivate': false});
      _replaceTask(updated);
      if (updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      await _refreshTaskData(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر مشاركة المهمة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> markTaskDone(String weddingPlanId, WeddingTask task) async {
    return updateTaskStatus(weddingPlanId, task, 'DONE');
  }

  Future<bool> reopenTask(String weddingPlanId, WeddingTask task) async {
    final previousStatus = _lastMeaningfulStatuses[task.id];
    final nextStatus = previousStatus != null && previousStatus != 'DONE'
        ? previousStatus
        : 'TODO';
    return updateTaskStatus(weddingPlanId, task, nextStatus);
  }

  Future<bool> updateTaskStatus(
    String weddingPlanId,
    WeddingTask task,
    String nextStatus,
  ) async {
    final previousTask = _currentTask(task);
    final mutationVersion = _nextStatusMutationVersion(task.id);
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateTask(task.id, {'status': nextStatus});
      if (_isCurrentStatusMutation(task.id, mutationVersion)) {
        if (nextStatus == 'DONE' && previousTask.status != 'DONE') {
          _lastMeaningfulStatuses[task.id] = previousTask.status;
        }
        _replaceTask(updated);
        if (updated.id.startsWith('local-')) {
          _noticeMessage = CachePolicy.offlineWriteMessage;
        }
        await _refreshTaskData(weddingPlanId);
      }
      return true;
    } on ApiException catch (error) {
      if (_isCurrentStatusMutation(task.id, mutationVersion)) {
        _errorMessage = error.message;
      }
      return false;
    } catch (_) {
      if (_isCurrentStatusMutation(task.id, mutationVersion)) {
        _errorMessage = 'تعذر تحديث المهمة.';
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateTask({
    required String weddingPlanId,
    required WeddingTask task,
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
    required String status,
    required String priority,
  }) async {
    final normalizedCategory = _taskCategoryForPayload(taskCategory);
    final previousTask = _currentTask(task);
    final optimisticTask = previousTask.copyWith(
      title: title.trim(),
      description: description,
      dueDate: dueDate,
      taskCategory: normalizedCategory,
      assigneeUserId: assigneeUserId,
      assigneeName: assigneeName,
      assigneePhone: assigneePhone,
      assigneeRole: assigneeRole,
      responsibleName: responsibleName,
      responsiblePhone: responsiblePhone,
      responsibleSource: responsibleSource,
      status: status,
      priority: priority,
      updatedAt: DateTime.now(),
    );
    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'taskCategory': normalizedCategory,
      'status': status,
      'priority': priority,
    };
    if (task.id.startsWith('local-task-')) {
      payload.addAll(
        _responsibilityPayload(
          assigneeUserId: assigneeUserId,
          assigneeName: assigneeName,
          assigneePhone: assigneePhone,
          assigneeRole: assigneeRole,
          responsibleName: responsibleName,
          responsiblePhone: responsiblePhone,
          responsibleSource: responsibleSource,
        ),
      );
    } else {
      payload.addAll({
        'responsibleName': assigneeUserId == null ? responsibleName : null,
        'responsiblePhone': assigneeUserId == null ? responsiblePhone : null,
        'responsibleSource': assigneeUserId == null ? responsibleSource : null,
      });
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    _replaceTask(optimisticTask);
    notifyListeners();

    try {
      var updated = await _api.updateTask(task.id, payload);
      if (!task.id.startsWith('local-task-') &&
          _assigneeChanged(previousTask.assigneeUserId, assigneeUserId)) {
        // The field update above is already saved; the assignment is a
        // separate request. If it fails, show the saved fields and say that
        // only the assignee was not changed, so a retry is understood.
        final fieldsSaved = updated;
        try {
          updated = await _api.assignTask(
            task.id,
            assigneeUserId: assigneeUserId,
            assigneeName: assigneeName,
            assigneePhone: assigneePhone,
            assigneeRole: assigneeRole,
          );
        } catch (error) {
          _replaceTask(fieldsSaved);
          final reason = error is ApiException
              ? error.message
              : 'تعذر تغيير المسؤول.';
          await _refreshTaskData(weddingPlanId);
          _errorMessage = 'تم حفظ تفاصيل المهمة، لكن لم يتغير المسؤول: $reason';
          return false;
        }
      }
      _replaceTask(updated);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      } else if (updated.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      await _refreshTaskData(weddingPlanId);
      return true;
    } on ApiException catch (error) {
      _replaceTask(previousTask);
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _replaceTask(previousTask);
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
      await _refreshTaskData(weddingPlanId);
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

  Future<bool> addChecklistItem(WeddingTask task, String title) {
    return _changeChecklist(task, (current) async {
      final item = await _api.createChecklistItem(current, title);
      return [...current.checklist, item];
    });
  }

  Future<bool> updateChecklistItem(
    WeddingTask task,
    TaskChecklistItem item, {
    String? title,
    bool? isDone,
  }) {
    return _changeChecklist(task, (current) async {
      final updated = await _api.updateChecklistItem(
        current,
        item,
        title: title,
        isDone: isDone,
      );
      return [
        for (final entry in current.checklist)
          entry.id == updated.id ? updated : entry,
      ];
    });
  }

  Future<bool> removeChecklistItem(WeddingTask task, TaskChecklistItem item) {
    return _changeChecklist(task, (current) async {
      await _api.deleteChecklistItem(current, item);
      return [
        for (final entry in current.checklist)
          if (entry.id != item.id) entry,
      ];
    });
  }

  /// Applies one confirmed checklist change at a time. The task only shows
  /// what the server saved; a failure keeps it unchanged and says why.
  Future<bool> _changeChecklist(
    WeddingTask task,
    Future<List<TaskChecklistItem>> Function(WeddingTask current) change,
  ) async {
    if (_isSavingChecklist) return false;
    _isSavingChecklist = true;
    _checklistErrorMessage = null;
    notifyListeners();
    try {
      final checklist = await change(_currentTask(task));
      _replaceTask(_currentTask(task).copyWith(checklist: checklist));
      return true;
    } on ApiException catch (error) {
      _checklistErrorMessage = error.message;
      return false;
    } catch (_) {
      _checklistErrorMessage = 'تعذر حفظ القائمة الفرعية. حاول مرة أخرى.';
      return false;
    } finally {
      _isSavingChecklist = false;
      notifyListeners();
    }
  }

  WeddingTask _currentTask(WeddingTask fallback) {
    for (final task in _tasks) {
      if (task.id == fallback.id) return task;
    }
    return fallback;
  }

  void _replaceTask(WeddingTask updated) {
    final index = _tasks.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      _tasks = [updated, ..._tasks];
      return;
    }
    _tasks = [
      for (var i = 0; i < _tasks.length; i++)
        if (i == index) updated else _tasks[i],
    ];
  }

  int _nextStatusMutationVersion(String taskId) {
    final next = (_statusMutationVersions[taskId] ?? 0) + 1;
    _statusMutationVersions[taskId] = next;
    return next;
  }

  bool _isCurrentStatusMutation(String taskId, int mutationVersion) {
    return _statusMutationVersions[taskId] == mutationVersion;
  }

  Future<void> _refreshTaskData(String weddingPlanId) async {
    try {
      _timeline = await _api.getTimeline(weddingPlanId);
      _summary = await _api.getTaskSummary(weddingPlanId);
    } on Object catch (error) {
      _summary = TaskSummary.fromTasks(
        weddingPlanId: weddingPlanId,
        tasks: _tasks,
      );
      _errorMessage = _loadErrorMessage(error);
    }
  }

  String? _taskCategoryForPayload(String? taskCategory) {
    final trimmed = taskCategory?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'GENERAL') {
      return null;
    }
    return trimmed;
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
        'responsibleName': null,
        'responsiblePhone': null,
        'responsibleSource': null,
      };
    }

    return {
      'assigneeUserId': null,
      'assigneeName': null,
      'assigneePhone': null,
      'assigneeRole': null,
      if (_hasValue(responsibleName))
        'responsibleName': responsibleName!.trim()
      else
        'responsibleName': null,
      if (_hasValue(responsiblePhone))
        'responsiblePhone': responsiblePhone!.trim()
      else
        'responsiblePhone': null,
      if (_hasValue(responsibleSource))
        'responsibleSource': responsibleSource!.trim()
      else
        'responsibleSource': null,
    };
  }

  bool _assigneeChanged(String? previous, String? next) {
    return (previous?.trim().isNotEmpty == true ? previous!.trim() : null) !=
        (next?.trim().isNotEmpty == true ? next!.trim() : null);
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

bool _isLocalGuestPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}
