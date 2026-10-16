part of 'create_task_screen.dart';

/// The edited task and its privacy. V1 checklist 4.10: the owner or the
/// partner may keep a new task to themselves; a private task can join the
/// shared plan later, never the other way round.
extension _CreateTaskPrivacy on _CreateTaskScreenState {
  List<Widget> _privacySection(TaskTimelineProvider provider) {
    final editing = _isEditMode ? _currentEditingTask(provider) : null;
    if (editing != null && editing.isPrivate) {
      return [
        const SizedBox(height: AppTheme.space10),
        const AarastStatusPill(
          key: ValueKey('task-private-banner'),
          label: 'مهمة خاصة بك: لا يراها شريكك ولا تدخل في أرقامه.',
          icon: LucideIcons.lock,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('task-share-with-plan'),
            onPressed: provider.isSubmitting
                ? null
                : () => _shareWithPlan(editing),
            icon: const Icon(LucideIcons.users),
            label: const Text('مشاركتها مع الخطة'),
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
      const SizedBox(height: AppTheme.space10),
      SwitchListTile(
        key: const ValueKey('task-private'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(LucideIcons.lock),
        title: const Text('مهمة خاصة بي'),
        subtitle: const Text(
          'لا يراها شريكك ولا تصله تذكيراتها. تستطيع مشاركتها لاحقًا.',
        ),
        value: _isPrivate,
        onChanged: (value) => _mutateDraft(() => _isPrivate = value),
      ),
    ];
  }

  Future<void> _shareWithPlan(WeddingTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('مشاركة المهمة مع الخطة؟'),
        content: const Text(
          'سيراها شريكك وتدخل في مهام الخطة. لا يمكن إرجاعها خاصة بعد ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('مشاركة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<TaskTimelineProvider>();
    final ok = await provider.shareTaskWithPlan(widget.weddingPlanId, task);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'صارت المهمة مشتركة مع الخطة.');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر مشاركة المهمة.',
      );
    }
  }

  /// A private task stays with its account, so no one else in the plan can
  /// be made responsible for it. Says so and returns true when the form
  /// tries.
  bool _privateTaskGivenAway(
    TaskTimelineProvider provider,
    bool hasParticipant,
    String? assigneeUserId,
  ) {
    final keepsPrivate = _isEditMode
        ? _currentEditingTask(provider)?.isPrivate == true
        : _isPrivate;
    final currentUserId = context.read<AuthController?>()?.user?.id;
    if (!keepsPrivate || !hasParticipant || assigneeUserId == currentUserId) {
      return false;
    }
    AarastToast.showError(
      context,
      'المهمة الخاصة تبقى لك وحدك. اجعل نفسك المسؤول عنها، أو شاركها مع الخطة أولًا.',
    );
    return true;
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
