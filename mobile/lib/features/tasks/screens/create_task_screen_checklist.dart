part of 'create_task_screen.dart';

extension _CreateTaskChecklist on _CreateTaskScreenState {
  /// The checklist of the task being edited, read live from the provider so
  /// each saved step shows at once. A new task, a device-only task and a
  /// device-only plan have no server checklist yet, so nothing is shown.
  List<Widget> _checklistSection(TaskTimelineProvider provider) {
    final editing = _editingTask(provider);
    if (editing == null ||
        editing.id.startsWith('local-') ||
        AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
      return const [];
    }
    final task = provider.tasks.firstWhere(
      (item) => item.id == editing.id,
      orElse: () => editing,
    );
    return [
      const SizedBox(height: AppTheme.space10),
      TaskChecklistSection(
        items: task.checklist,
        saving: provider.isSavingChecklist,
        errorMessage: provider.checklistErrorMessage,
        onAdd: (title) => provider.addChecklistItem(task, title),
        onToggle: (item, isDone) =>
            provider.updateChecklistItem(task, item, isDone: isDone),
        onRename: (item, title) =>
            provider.updateChecklistItem(task, item, title: title),
        onRemove: (item) => provider.removeChecklistItem(task, item),
      ),
    ];
  }
}
