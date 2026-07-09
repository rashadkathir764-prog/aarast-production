import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../sharing/models/shared_member.dart';
import '../../sharing/providers/sharing_provider.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    required this.weddingPlanId,
    this.taskId,
    this.initialTask,
    super.key,
  });

  final String weddingPlanId;
  final String? taskId;
  final WeddingTask? initialTask;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _responsibleNameController = TextEditingController(text: 'أنا');
  final _responsiblePhoneController = TextEditingController();

  DateTime? _dueDate;
  String _priority = 'MEDIUM';
  String _category = 'GENERAL';
  String _status = 'TODO';
  String? _selectedAssigneeUserId;
  String? _selectedAssigneeName;
  String? _selectedAssigneePhone;
  String? _selectedAssigneeRole;
  ContactPhoneSource _responsibleSource = ContactPhoneSource.manual;
  bool _didPrefill = false;
  bool _didRequestMembers = false;

  // مصدر واحد لأيقونات التصنيف — نفس أيقونات Lucide المستخدمة في بطاقة
  // المهمة (taskCategoryIcon) حتى يبقى التصنيف متطابقًا بين القائمة والنموذج.
  static final _categories = [
    _TaskCategory('GENERAL', 'عامة', LucideIcons.layoutGrid),
    _TaskCategory('VENUE', 'القاعة', taskCategoryIcon('VENUE')),
    _TaskCategory('GUESTS', 'الضيوف', taskCategoryIcon('GUESTS')),
    _TaskCategory('MONEY', 'المال', taskCategoryIcon('MONEY')),
    _TaskCategory('PROVIDERS', 'الموردين', taskCategoryIcon('PROVIDERS')),
    _TaskCategory('ATTIRE', 'الملابس', taskCategoryIcon('ATTIRE')),
    _TaskCategory('PHOTOGRAPHY', 'التصوير', taskCategoryIcon('PHOTOGRAPHY')),
    _TaskCategory('CATERING', 'الضيافة', taskCategoryIcon('CATERING')),
    _TaskCategory('DECOR', 'الزينة', taskCategoryIcon('DECOR')),
    _TaskCategory('DOCUMENTS', 'المستندات', taskCategoryIcon('DOCUMENTS')),
  ];

  bool get _isEditMode => widget.taskId != null || widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _prefillTask(task);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMembersIfAvailable();

    if (!_isEditMode || _didPrefill) return;

    final taskId = widget.taskId;
    if (taskId != null) {
      final provider = context.read<TaskTimelineProvider>();
      for (final task in provider.tasks) {
        if (task.id == taskId) {
          _prefillTask(task);
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _responsibleNameController.dispose();
    _responsiblePhoneController.dispose();
    super.dispose();
  }

  Future<void> _showCalendarPicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = _dueDate ?? now;

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تاريخ استحقاق المهمة',
                    icon: LucideIcons.calendarCheck,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.burgundy,
                        onPrimary: Colors.white,
                        surface: AppTheme.surface,
                        onSurface: AppTheme.ink,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                      onDateChanged: (date) => tempDate = date,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AarastButton(
                    label: 'تأكيد التاريخ',
                    icon: LucideIcons.check,
                    onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) setState(() => _dueDate = selected);
  }

  Future<void> _showCategoryPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'فئة المهمة',
                    icon: LucideIcons.tag,
                  ),
                  const SizedBox(height: 14),
                  for (final category in _categories)
                    _CategoryRow(
                      category: category,
                      selected: category.id == _category,
                      onTap: () => Navigator.of(sheetContext).pop(category.id),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) setState(() => _category = selected);
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
    _responsibleSource = _sourceFromTask(task);
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
    return _categories.any((category) => category.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final sharingProvider = context.watch<SharingProvider?>();
    final category = _categories.firstWhere((item) => item.id == _category);
    final participants = _membersForPlan(
      sharingProvider?.members ?? const <SharedMember>[],
      widget.weddingPlanId,
    );

    return AarastScreenFrame(
      maxWidth: 480,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(LucideIcons.arrowRight),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'تعديل المهمة' : 'إضافة مهمة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TaskHero(),
                    const SizedBox(height: 14),
                    AarastCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleController,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المهمة',
                              hintText: 'مثال: تأكيد قائمة المدعوين',
                              prefixIcon: Icon(LucideIcons.pencil),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'عنوان المهمة مطلوب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final categoryField = _SelectorField(
                                label: 'الفئة',
                                value: category.label,
                                icon: category.icon,
                                selected: true,
                                onTap: _showCategoryPicker,
                              );
                              final dateField = _SelectorField(
                                label: 'التاريخ',
                                value: _dueDate == null
                                    ? 'لم يحدد بعد'
                                    : _formatDate(_dueDate!),
                                icon: LucideIcons.calendar,
                                selected: _dueDate != null,
                                onTap: _showCalendarPicker,
                              );

                              if (constraints.maxWidth < 280) {
                                return Column(
                                  children: [
                                    categoryField,
                                    const SizedBox(height: 12),
                                    dateField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: categoryField),
                                  const SizedBox(width: 12),
                                  Expanded(child: dateField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'أولوية المهمة',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _PriorityChip(
                                label: 'منخفضة',
                                icon: LucideIcons.leaf,
                                color: AppTheme.success,
                                selected: _priority == 'LOW',
                                onTap: () {
                                  setState(() => _priority = 'LOW');
                                },
                              ),
                              const SizedBox(width: 8),
                              _PriorityChip(
                                label: 'متوسطة',
                                icon: LucideIcons.gripHorizontal,
                                color: AppTheme.gold,
                                selected: _priority == 'MEDIUM',
                                onTap: () {
                                  setState(() => _priority = 'MEDIUM');
                                },
                              ),
                              const SizedBox(width: 8),
                              _PriorityChip(
                                label: 'عاجلة',
                                icon: LucideIcons.zap,
                                color: AppTheme.danger,
                                selected: _priority == 'HIGH',
                                onTap: () {
                                  setState(() => _priority = 'HIGH');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ResponsibleSection(
                            participants: participants,
                            selectedAssigneeUserId: _selectedAssigneeUserId,
                            selectedAssigneeRole: _selectedAssigneeRole,
                            responsibleNameController:
                                _responsibleNameController,
                            responsiblePhoneController:
                                _responsiblePhoneController,
                            canInviteResponsible: _canInviteResponsible,
                            onSelectParticipant: _showParticipantPicker,
                            onManualChanged: _clearSelectedParticipant,
                            onDraftChanged: _handleResponsibleDraft,
                            onInvite: _inviteResponsibleAsParticipant,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            textAlign: TextAlign.right,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                              hintText:
                                  'أضف أي تفاصيل تساعدك على تنفيذ المهمة...',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AarastStatusPill(
                              label: provider.errorMessage!,
                              color: AppTheme.danger,
                              icon: LucideIcons.alertCircle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المهمة',
                      icon: _isEditMode
                          ? LucideIcons.save
                          : LucideIcons.calendarCheck,
                      isLoading: provider.isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.tasks(widget.weddingPlanId));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<TaskTimelineProvider>();
    final description = _descriptionController.text.trim();
    final normalizedDescription = description.isEmpty ? null : description;
    final normalizedResponsiblePhone = _normalizedResponsiblePhone();
    final hasParticipant = _selectedAssigneeUserId?.trim().isNotEmpty == true;
    final responsibleName = hasParticipant
        ? null
        : _responsibleNameForPayload();
    final responsibleSource = hasParticipant ? null : _responsibleSource.name;
    if (!AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId) &&
        !hasParticipant &&
        (responsibleName != null || normalizedResponsiblePhone != null)) {
      AarastToast.showError(
        context,
        'حفظ مسؤول يدوي للحسابات يحتاج دعماً من الخادم؛ اختر مشاركاً من الخطة أو احفظ المهمة بدون رقم.',
      );
      return;
    }
    final task = _editingTask(provider);
    final saved = _isEditMode
        ? task != null &&
              await provider.updateTask(
                weddingPlanId: widget.weddingPlanId,
                task: task,
                title: _titleController.text.trim(),
                description: normalizedDescription,
                dueDate: _dueDate,
                taskCategory: _category,
                assigneeUserId: _selectedAssigneeUserId,
                assigneeName: _selectedAssigneeName,
                assigneePhone: _selectedAssigneePhone,
                assigneeRole: _selectedAssigneeRole,
                responsibleName: responsibleName,
                responsiblePhone: hasParticipant
                    ? null
                    : normalizedResponsiblePhone,
                responsibleSource: responsibleSource,
                status: _status,
                priority: _priority,
              )
        : await provider.createTask(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            description: normalizedDescription,
            dueDate: _dueDate,
            taskCategory: _category,
            assigneeUserId: _selectedAssigneeUserId,
            assigneeName: _selectedAssigneeName,
            assigneePhone: _selectedAssigneePhone,
            assigneeRole: _selectedAssigneeRole,
            responsibleName: responsibleName,
            responsiblePhone: hasParticipant
                ? null
                : normalizedResponsiblePhone,
            responsibleSource: responsibleSource,
            status: 'TODO',
            priority: _priority,
          );

    if (_isEditMode && task == null && mounted) {
      AarastToast.showError(context, 'تعذر فتح المهمة للتعديل');
      return;
    }

    if (saved && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        AarastToast.showSuccess(context, notice);
      }
      _goBack();
    }
  }

  Future<void> _showParticipantPicker(List<SharedMember> participants) async {
    FocusScope.of(context).unfocus();
    if (participants.isEmpty) return;

    final selected = await showModalBottomSheet<SharedMember>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),
                const AarastSectionHeader(
                  title: 'اختيار مسؤول من المشاركين',
                  icon: LucideIcons.users,
                ),
                const SizedBox(height: 12),
                for (final member in participants) ...[
                  _ParticipantRow(
                    member: member,
                    selected: member.userId == _selectedAssigneeUserId,
                    onTap: () => Navigator.of(sheetContext).pop(member),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedAssigneeUserId = selected.userId;
      _selectedAssigneeName = selected.displayName;
      _selectedAssigneePhone = selected.user?.phone;
      _selectedAssigneeRole = selected.role;
      _responsibleNameController.text = selected.displayName;
      _responsiblePhoneController.text = selected.user?.phone ?? '';
      _responsibleSource = ContactPhoneSource.planContact;
    });
  }

  void _handleResponsibleDraft(ContactPhoneDraft draft) {
    setState(() {
      _responsibleSource = draft.source;
      if (draft.source != ContactPhoneSource.planContact) {
        _clearSelectedParticipant(updateState: false);
      }
    });
  }

  void _clearSelectedParticipant({bool updateState = true}) {
    void clear() {
      _selectedAssigneeUserId = null;
      _selectedAssigneeName = null;
      _selectedAssigneePhone = null;
      _selectedAssigneeRole = null;
      if (_responsibleSource == ContactPhoneSource.planContact) {
        _responsibleSource = ContactPhoneSource.manual;
      }
    }

    if (updateState) {
      setState(clear);
    } else {
      clear();
    }
  }

  Future<void> _inviteResponsibleAsParticipant() async {
    final allowed = await AuthActionGuard.requireAccount(
      context,
      reason: 'دعوة مسؤول المهمة كمشارك في الخطة تحتاج حساباً وصلاحيات مشاركة.',
    );
    if (!allowed || !mounted) return;
    context.push(AppRouter.addSharedMember(widget.weddingPlanId));
  }

  String? _normalizedResponsiblePhone() {
    return PhoneNumberUtils.normalizeOptional(_responsiblePhoneController.text);
  }

  String? _responsibleNameForPayload() {
    final value = _responsibleNameController.text.trim();
    if (value.isEmpty || value == 'أنا') return null;
    return value;
  }

  bool get _canInviteResponsible {
    if (_selectedAssigneeUserId?.trim().isNotEmpty == true) return false;
    return _responsiblePhoneController.text.trim().isNotEmpty;
  }

  void _loadMembersIfAvailable() {
    if (_didRequestMembers ||
        AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
      return;
    }
    final sharingProvider = context.read<SharingProvider?>();
    if (sharingProvider == null) return;
    _didRequestMembers = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sharingProvider.loadMembers(widget.weddingPlanId);
    });
  }

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
}

class _TaskHero extends StatelessWidget {
  const _TaskHero();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppTheme.burgundySoft.withAlpha(120),
      border: Border.all(color: AppTheme.burgundy.withAlpha(35)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              LucideIcons.clipboardCheck,
              color: AppTheme.burgundy,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظّم كل تفصيل بخطوة مدروسة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المهام الواضحة تجعل يومك أسهل وأهدأ.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibleSection extends StatelessWidget {
  const _ResponsibleSection({
    required this.participants,
    required this.selectedAssigneeUserId,
    required this.selectedAssigneeRole,
    required this.responsibleNameController,
    required this.responsiblePhoneController,
    required this.canInviteResponsible,
    required this.onSelectParticipant,
    required this.onManualChanged,
    required this.onDraftChanged,
    required this.onInvite,
  });

  final List<SharedMember> participants;
  final String? selectedAssigneeUserId;
  final String? selectedAssigneeRole;
  final TextEditingController responsibleNameController;
  final TextEditingController responsiblePhoneController;
  final bool canInviteResponsible;
  final ValueChanged<List<SharedMember>> onSelectParticipant;
  final VoidCallback onManualChanged;
  final ValueChanged<ContactPhoneDraft> onDraftChanged;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final selectedParticipant = _findSelectedParticipant(
      participants,
      selectedAssigneeUserId,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.userCheck,
                color: AppTheme.burgundy,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المسؤول عن المهمة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selectedParticipant != null)
                _ParticipantBadge(role: selectedAssigneeRole),
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SelectorField(
              label: 'مشارك من الخطة',
              value: selectedParticipant == null
                  ? 'اختر مشاركاً موجوداً'
                  : selectedParticipant.displayName,
              icon: LucideIcons.users,
              selected: selectedParticipant != null,
              onTap: () => onSelectParticipant(participants),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: responsibleNameController,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onManualChanged(),
            decoration: const InputDecoration(
              labelText: 'اسم المسؤول',
              hintText: 'أنا أو اسم الشخص المسؤول',
              prefixIcon: Icon(LucideIcons.user),
            ),
          ),
          const SizedBox(height: 12),
          ContactPhoneField(
            phoneController: responsiblePhoneController,
            nameController: responsibleNameController,
            label: 'رقم المسؤول',
            hintText: '77xxxxxxx',
            helperText: 'يمكن ترك الرقم فارغاً؛ يظهر كرقم متابعة للمسؤول فقط.',
            onDraftChanged: onDraftChanged,
          ),
          if (canInviteResponsible) ...[
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.burgundy,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onInvite,
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text('دعوته كمشارك في الخطة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final SharedMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.burgundySoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: selected ? AppTheme.burgundy : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? LucideIcons.checkCircle
                    : LucideIcons.user,
                color: selected ? AppTheme.burgundy : AppTheme.gold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      sharedMemberRoleLabel(member.role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantBadge extends StatelessWidget {
  const _ParticipantBadge({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final roleLabel = role?.trim().isNotEmpty == true
        ? sharedMemberRoleLabel(role!.trim())
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.goldSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Text(
        roleLabel == null ? 'مشارك في الخطة' : 'مشارك في الخطة',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.burgundy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(25) : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppTheme.muted, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        color: selected ? AppTheme.burgundySoft : AppTheme.surface,
        border: Border.all(color: selected ? AppTheme.burgundy : AppTheme.border),
        onTap: onTap,
        child: Row(
          children: [
            Icon(category.icon, color: AppTheme.burgundy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.burgundy : AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(LucideIcons.checkCircle, color: AppTheme.burgundy),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _TaskCategory {
  const _TaskCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}

ContactPhoneSource _sourceFromTask(WeddingTask task) {
  if (task.hasResponsibleParticipant) return ContactPhoneSource.planContact;
  final source = task.responsibleSource?.trim();
  return switch (source) {
    'deviceContact' => ContactPhoneSource.deviceContact,
    'planContact' => ContactPhoneSource.planContact,
    _ => ContactPhoneSource.manual,
  };
}

List<SharedMember> _membersForPlan(
  List<SharedMember> members,
  String weddingPlanId,
) {
  return members
      .where((member) => member.weddingPlanId == weddingPlanId)
      .toList(growable: false);
}

SharedMember? _findSelectedParticipant(
  List<SharedMember> members,
  String? assigneeUserId,
) {
  final id = assigneeUserId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final member in members) {
    if (member.userId == id) return member;
  }
  return null;
}
