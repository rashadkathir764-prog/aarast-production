part of 'create_task_screen.dart';

/// The edited task and its privacy. V1 checklist 4.10: the owner or the
/// partner may keep a new task to themselves (w25); a private task can join
/// the shared plan later, never the other way round.
extension _CreateTaskPrivacy on _CreateTaskScreenState {
  List<Widget> _privacySection(TaskTimelineProvider provider) {
    final editing = _isEditMode ? _currentEditingTask(provider) : null;
    if (editing != null && editing.isPrivate) {
      return [
        const SizedBox(height: 14),
        const JourneyNote(
          key: ValueKey('task-private-banner'),
          text: 'مهمة خاصة بك: ما يشوفها شريكك ولا تدخل في أرقامه.',
          icon: LucideIcons.lock,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('task-share-with-plan'),
            label: context.say('شاركها مع الخطة', 'شاركيها مع الخطة'),
            icon: LucideIcons.users,
            color: context.accent.primary,
            onPressed: provider.isSubmitting
                ? null
                : () => _shareWithPlan(editing),
          ),
        ),
      ];
    }
    final canKeepPrivate =
        !_isEditMode &&
        provider.summary.weddingPlanId == widget.weddingPlanId &&
        provider.summary.canKeepPrivateTask;
    if (!canKeepPrivate) return const [];
    return [
      const SizedBox(height: 14),
      JourneyBox(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: SwitchListTile(
          key: const ValueKey('task-private'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(
            LucideIcons.eyeOff,
            color: AarastV3Color.brandAccentStrong,
          ),
          title: Text(
            'خاصة',
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          subtitle: Text(
            'ما يشوفها غيرك، حتى المشاركين',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          value: _isPrivate,
          onChanged: (value) => _mutateDraft(() {
            _isPrivate = value;
            if (value) _who = _whoMe;
          }),
        ),
      ),
    ];
  }

  /// Whether the task stays with its owner only.
  bool _keepsPrivate(TaskTimelineProvider provider) => _isEditMode
      ? _currentEditingTask(provider)?.isPrivate == true
      : _isPrivate;

  Future<void> _shareWithPlan(WeddingTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: Text(context.say('تشاركها مع الخطة؟', 'تشاركينها مع الخطة؟')),
        content: const Text(
          'بيشوفها شريكك وتدخل في مهام الخطة، وما ترجع خاصة بعدها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.say('شاركها', 'شاركيها')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<TaskTimelineProvider>();
    final ok = await provider.shareTaskWithPlan(widget.weddingPlanId, task);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'صارت المهمة مشتركة مع الخطة');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نشاركها',
      );
    }
  }

  /// The task the screen opened to edit, or null for a new task.
  WeddingTask? _editingTask(TaskTimelineProvider provider) {
    final task = widget.initialTask;
    if (task != null) return task;
    final taskId = widget.taskId;
    if (taskId == null) return null;
    for (final item in provider.tasks) {
      if (item.id == taskId) return item;
    }
    return null;
  }

  /// The edited task as the provider holds it now (after a share, say).
  WeddingTask? _currentEditingTask(TaskTimelineProvider provider) {
    final task = _editingTask(provider);
    if (task == null) return null;
    for (final item in provider.tasks) {
      if (item.id == task.id) return item;
    }
    return task;
  }
}
