// The extension is a private part of the owning State library and deliberately
// drives that State's visual draft status.
// ignore_for_file: invalid_use_of_protected_member

part of 'create_task_screen.dart';

/// «متى؟»: this week (by Thursday), this month (by its last day), a chosen
/// day, or no day yet. A time of day («بعد العصر») is not kept.
enum _When { week, month, date, none }

DateTime _endOfWeek(DateTime today) {
  final days = (DateTime.thursday - today.weekday) % 7;
  return DateUtils.dateOnly(today).add(Duration(days: days));
}

DateTime _endOfMonth(DateTime today) =>
    DateTime(today.year, today.month + 1, 0);

extension _CreateTaskDraftPersistence on _CreateTaskScreenState {
  bool get _isEditMode => widget.taskId != null || widget.initialTask != null;

  /// The day the chosen «متى؟» saves as.
  DateTime? get _dueDate => switch (_when) {
    _When.week => _endOfWeek(DateTime.now()),
    _When.month => _endOfMonth(DateTime.now()),
    _When.date => _pickedDate,
    _When.none => null,
  };

  void _showSaveSuccess(TaskTimelineProvider provider) {
    final router = GoRouter.of(context);
    AarastFormSuccess.show(
      context,
      message:
          provider.noticeMessage ??
          (_isEditMode ? 'انحفظت المهمة' : 'انضافت المهمة'),
      nextLabel: _isEditMode ? null : context.say('أضف ثانية', 'أضيفي ثانية'),
      onNext: _isEditMode
          ? null
          : () => router.push(AppRouter.createTask(widget.weddingPlanId)),
    );
  }

  void _prefillTask(WeddingTask task, String? currentUserId) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _assigneeUserId = task.assigneeUserId;
    _assigneeName = task.assigneeName;
    _assigneePhone = task.assigneePhone;
    _assigneeRole = task.assigneeRole;
    _who = _whoForTask(task, currentUserId);
    _pickedDate = task.dueDate;
    _when = task.dueDate == null ? _When.none : _When.date;
    _priority = task.priority;
    _category = task.taskCategory;
    _status = task.status;
    _didPrefill = true;
  }

  void _configureDraft() {
    if (_didConfigureDraft || _isEditMode) return;
    _didConfigureDraft = true;
    final store = context.read<AarastFormDraftStore?>();
    if (store == null) return;
    _draft = AarastFormDraftCoordinator(
      store: store,
      scope: 'task:${widget.weddingPlanId}:new',
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    final data = await _draft?.restore();
    if (!mounted || data == null) return;
    _restoringDraft = true;
    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _otherNameController.text = data['otherName']?.toString() ?? '';
    _otherPhoneController.text = data['otherPhone']?.toString() ?? '';
    setState(() {
      _who = data['who']?.toString() ?? _who;
      _when = _When.values.firstWhere(
        (value) => value.name == data['when']?.toString(),
        orElse: () => _when,
      );
      _pickedDate = DateTime.tryParse(data['date']?.toString() ?? '');
      _isPrivate = data['private'] == true;
      _otherSource = ContactPhoneSource.values.firstWhere(
        (source) => source.name == data['otherSource']?.toString(),
        orElse: () => ContactPhoneSource.manual,
      );
    });
    _restoringDraft = false;
  }

  void _scheduleDraft() {
    if (_restoringDraft) return;
    _draft?.schedule({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'who': _who,
      'when': _when.name,
      'date': _pickedDate?.toIso8601String(),
      'private': _isPrivate,
      'otherName': _otherNameController.text,
      'otherPhone': _otherPhoneController.text,
      'otherSource': _otherSource.name,
    });
  }

  void _mutateDraft(VoidCallback change) {
    setState(change);
    _scheduleDraft();
  }
}
