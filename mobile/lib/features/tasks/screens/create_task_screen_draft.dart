// The extension is a private part of the owning State library and deliberately
// drives that State's visual draft status.
// ignore_for_file: invalid_use_of_protected_member

part of 'create_task_screen.dart';

// مصدر واحد لأيقونات التصنيف — نفس أيقونات Lucide المستخدمة في بطاقة
// المهمة حتى يبقى التصنيف متطابقًا بين القائمة والنموذج.
final _createTaskCategories = <CreateTaskCategory>[
  const CreateTaskCategory('GENERAL', 'عامة', LucideIcons.layoutGrid),
  CreateTaskCategory('VENUE', 'القاعة', taskCategoryIcon('VENUE')),
  CreateTaskCategory('GUESTS', 'الضيوف', taskCategoryIcon('GUESTS')),
  CreateTaskCategory('MONEY', 'المال', taskCategoryIcon('MONEY')),
  CreateTaskCategory('PROVIDERS', 'الموردين', taskCategoryIcon('PROVIDERS')),
  CreateTaskCategory('ATTIRE', 'الملابس', taskCategoryIcon('ATTIRE')),
  CreateTaskCategory('PHOTOGRAPHY', 'التصوير', taskCategoryIcon('PHOTOGRAPHY')),
  CreateTaskCategory('CATERING', 'الضيافة', taskCategoryIcon('CATERING')),
  CreateTaskCategory('DECOR', 'الزينة', taskCategoryIcon('DECOR')),
  CreateTaskCategory('DOCUMENTS', 'المستندات', taskCategoryIcon('DOCUMENTS')),
];

extension _CreateTaskDraftPersistence on _CreateTaskScreenState {
  bool get _isEditMode => widget.taskId != null || widget.initialTask != null;

  void _showSaveSuccess(TaskTimelineProvider provider) {
    final router = GoRouter.of(context);
    AarastFormSuccess.show(
      context,
      message:
          provider.noticeMessage ??
          (_isEditMode ? 'تم حفظ تعديلات المهمة.' : 'تمت إضافة المهمة.'),
      nextLabel: _isEditMode ? null : 'إضافة أخرى',
      onNext: _isEditMode
          ? null
          : () => router.push(AppRouter.createTask(widget.weddingPlanId)),
    );
  }

  void _prefillTask(WeddingTask task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _responsibleNameController.text = task.responsibleLabel;
    _responsiblePhoneController.text =
        task.responsiblePhone ?? task.assigneePhone ?? '';
    _selectedAssigneeUserId = task.assigneeUserId;
    _selectedAssigneeName = task.assigneeName;
    _selectedAssigneePhone = task.assigneePhone;
    _selectedAssigneeRole = task.assigneeRole;
    _responsibleSource = contactPhoneSourceFromTask(task);
    _dueDate = task.dueDate;
    _priority = task.priority;
    _category = _categoryExists(task.taskCategory)
        ? task.taskCategory!
        : 'GENERAL';
    _status = task.status;
    _didPrefill = true;
  }

  bool _categoryExists(String? id) {
    if (id == null || id.isEmpty) return false;
    return _createTaskCategories.any((category) => category.id == id);
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
    _responsibleNameController.text =
        data['responsibleName']?.toString() ?? 'أنا';
    _responsiblePhoneController.text =
        data['responsiblePhone']?.toString() ?? '';
    final dueDate = DateTime.tryParse(data['dueDate']?.toString() ?? '');
    final category = data['category']?.toString();
    final priority = data['priority']?.toString();
    setState(() {
      _dueDate = dueDate;
      if (_categoryExists(category)) _category = category!;
      if (const ['LOW', 'MEDIUM', 'HIGH'].contains(priority)) {
        _priority = priority!;
      }
      _responsibleSource = ContactPhoneSource.values.firstWhere(
        (source) => source.name == data['responsibleSource']?.toString(),
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
      'responsibleName': _responsibleNameController.text,
      'responsiblePhone': _responsiblePhoneController.text,
      'responsibleSource': _responsibleSource.name,
      'dueDate': _dueDate?.toIso8601String(),
      'category': _category,
      'priority': _priority,
    });
  }

  void _mutateDraft(VoidCallback change) {
    setState(change);
    _scheduleDraft();
  }

  Widget _buildLiveSummary() {
    return AarastV3LiveSummary(
      items: [
        AarastV3SummaryItem(
          label: 'المهمة',
          value: _titleController.text.trim().isEmpty
              ? 'لم تُكتب بعد'
              : _titleController.text.trim(),
        ),
        AarastV3SummaryItem(
          label: 'الموعد',
          value: _dueDate == null ? 'غير محدد' : formatTaskDueDate(_dueDate!),
        ),
        AarastV3SummaryItem(
          label: 'المسؤول',
          value: _responsibleNameController.text.trim().isEmpty
              ? 'أنا'
              : _responsibleNameController.text.trim(),
        ),
      ],
    );
  }
}
