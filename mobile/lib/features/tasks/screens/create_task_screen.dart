import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../../sharing/providers/sharing_provider.dart';
import '../../wedding_plans/utils/plan_pulse_sync.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../widgets/create_task_components.dart';

part 'create_task_screen_draft.dart';

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
  bool _didPrefill = false, _didRequestMembers = false;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _prefillTask(task);
    }
    for (final controller in [
      _titleController,
      _descriptionController,
      _responsibleNameController,
      _responsiblePhoneController,
    ]) {
      controller.addListener(_handleTextChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureDraft();
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
    for (final controller in [
      _titleController,
      _descriptionController,
      _responsibleNameController,
      _responsiblePhoneController,
    ]) {
      controller
        ..removeListener(_handleTextChanged)
        ..dispose();
    }
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _showCalendarPicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = _dueDate ?? now;

    final selected = await showAarastBottomSheet<DateTime>(
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
                  const CreateTaskSheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تاريخ استحقاق المهمة',
                    icon: LucideIcons.calendarCheck,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.brand,
                        onPrimary: Colors.white,
                        surface: AppTheme.surfaceRaised,
                        onSurface: AppTheme.textPrimary,
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

    if (selected != null && mounted) {
      _mutateDraft(() => _dueDate = selected);
    }
  }

  Future<void> _showCategoryPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await showAarastBottomSheet<String>(
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
                  const CreateTaskSheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'فئة المهمة',
                    icon: LucideIcons.tag,
                  ),
                  const SizedBox(height: 14),
                  for (final category in _createTaskCategories)
                    CreateTaskCategoryRow(
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

    if (selected != null && mounted) {
      _mutateDraft(() => _category = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final sharingProvider = context.watch<SharingProvider?>();
    final currentUserId = context.watch<AuthController?>()?.user?.id;
    final category = _createTaskCategories.firstWhere(
      (item) => item.id == _category,
    );
    final participants = sharedMembersForPlan(
      sharingProvider?.members ?? const <SharedMember>[],
      widget.weddingPlanId,
    );
    final selfMember =
        _selectedAssigneeUserId == null &&
            isSelfTaskLabel(_responsibleNameController.text)
        ? findCurrentSharedMember(participants, currentUserId)
        : null;

    return AarastScreenFrame(
      maxWidth: 480,
      bottomNavigationBar: AarastV3FormActionBar(
        maxWidth: 480,
        label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المهمة',
        icon: _isEditMode ? LucideIcons.save : LucideIcons.calendarCheck,
        loading: provider.isSubmitting,
        onPressed: provider.isSubmitting ? null : _submit,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: AarastPageHeader(
                title: _isEditMode ? 'تعديل المهمة' : 'مهمة جديدة',
                subtitle: 'اكتب المطلوب، ثم حدّد متى وأولوية التنفيذ.',
                showBack: true,
                onBack: _goBack,
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
                    if (_draft != null) ...[
                      AarastV3DraftStatusLine(status: _draft!.status),
                      const SizedBox(height: AppTheme.space10),
                    ],
                    const AarastV3FocusPrompt(
                      question: 'ما المهمة التي تريد حسمها؟',
                      supportingText:
                          'اكتب القرار أولًا، ثم أضف الموعد والمسؤول بقدر ما تعرفه الآن.',
                      icon: LucideIcons.listChecks,
                    ),
                    const SizedBox(height: AppTheme.space10),
                    AarastV3FormSurface(
                      children: [
                        Column(
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
                            const SizedBox(height: AppTheme.space10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final categoryField = CreateTaskSelectorField(
                                  label: 'الفئة',
                                  value: category.label,
                                  icon: category.icon,
                                  selected: true,
                                  onTap: _showCategoryPicker,
                                );
                                final dateField = CreateTaskSelectorField(
                                  label: 'التاريخ',
                                  value: _dueDate == null
                                      ? 'لم يحدد بعد'
                                      : formatTaskDueDate(_dueDate!),
                                  icon: LucideIcons.calendar,
                                  selected: _dueDate != null,
                                  onTap: _showCalendarPicker,
                                );

                                if (constraints.maxWidth < 280) {
                                  return Column(
                                    children: [
                                      categoryField,
                                      const SizedBox(height: AppTheme.space10),
                                      dateField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: categoryField),
                                    const SizedBox(width: AppTheme.space10),
                                    Expanded(child: dateField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppTheme.space12),
                            const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'أولوية المهمة',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space8),
                            Row(
                              children: [
                                CreateTaskPriorityChip(
                                  label: 'منخفضة',
                                  icon: LucideIcons.leaf,
                                  color: AppTheme.success,
                                  selected: _priority == 'LOW',
                                  onTap: () {
                                    _mutateDraft(() => _priority = 'LOW');
                                  },
                                ),
                                const SizedBox(width: AppTheme.space6),
                                CreateTaskPriorityChip(
                                  label: 'متوسطة',
                                  icon: LucideIcons.gripHorizontal,
                                  color: AppTheme.focus,
                                  selected: _priority == 'MEDIUM',
                                  onTap: () {
                                    _mutateDraft(() => _priority = 'MEDIUM');
                                  },
                                ),
                                const SizedBox(width: AppTheme.space6),
                                CreateTaskPriorityChip(
                                  label: 'عاجلة',
                                  icon: LucideIcons.zap,
                                  color: AppTheme.danger,
                                  selected: _priority == 'HIGH',
                                  onTap: () {
                                    _mutateDraft(() => _priority = 'HIGH');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space10),
                    CreateTaskDetailsDisclosure(
                      initiallyExpanded:
                          _descriptionController.text.trim().isNotEmpty ||
                          _selectedAssigneeUserId != null ||
                          !isSelfTaskLabel(_responsibleNameController.text),
                      summary: _responsibleNameController.text.trim().isEmpty
                          ? 'أنا · بدون ملاحظات'
                          : '${_responsibleNameController.text.trim()} · تفاصيل إضافية',
                      child: Column(
                        children: [
                          CreateTaskResponsibleSection(
                            participants: participants,
                            selectedAssigneeUserId:
                                _selectedAssigneeUserId ?? selfMember?.userId,
                            selectedAssigneeRole:
                                _selectedAssigneeRole ?? selfMember?.role,
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
                          const SizedBox(height: AppTheme.space10),
                          TextFormField(
                            controller: _descriptionController,
                            textAlign: TextAlign.right,
                            minLines: 2,
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة قصيرة',
                              hintText: 'ما الذي يجب تذكره عند التنفيذ؟',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space14),
                    _buildLiveSummary(),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: AppTheme.space10),
                      AarastStatusPill(
                        label: provider.errorMessage!,
                        color: AppTheme.danger,
                        icon: LucideIcons.alertCircle,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTextChanged() {
    _scheduleDraft();
    if (mounted) setState(() {});
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
    var assigneeUserId = _selectedAssigneeUserId;
    var assigneeName = _selectedAssigneeName;
    var assigneePhone = _selectedAssigneePhone;
    var assigneeRole = _selectedAssigneeRole;
    var hasParticipant = assigneeUserId?.trim().isNotEmpty == true;
    if (!hasParticipant &&
        !AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId) &&
        isSelfTaskLabel(_responsibleNameController.text)) {
      final sharingProvider = context.read<SharingProvider?>();
      final currentUserId = context.read<AuthController?>()?.user?.id;
      final participants = sharedMembersForPlan(
        sharingProvider?.members ?? const <SharedMember>[],
        widget.weddingPlanId,
      );
      final selfMember = findCurrentSharedMember(participants, currentUserId);
      if (selfMember == null) {
        AarastToast.showError(
          context,
          'تعذر تحديد حسابك ضمن الخطة. انتظر تحميل المشاركين ثم حاول مجدداً.',
        );
        return;
      }
      assigneeUserId = selfMember.userId;
      assigneeName = selfMember.displayName;
      assigneePhone = selfMember.user?.phone;
      assigneeRole = selfMember.role;
      hasParticipant = true;
    }
    final responsibleName = hasParticipant
        ? null
        : _responsibleNameForPayload();
    final responsibleSource = hasParticipant ? null : _responsibleSource.name;
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
                assigneeUserId: assigneeUserId,
                assigneeName: assigneeName,
                assigneePhone: assigneePhone,
                assigneeRole: assigneeRole,
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
            assigneeUserId: assigneeUserId,
            assigneeName: assigneeName,
            assigneePhone: assigneePhone,
            assigneeRole: assigneeRole,
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
      publishTaskPlanPulse(
        context,
        weddingPlanId: widget.weddingPlanId,
        summary: provider.summary,
      );
      await _draft?.clear();
      if (!mounted) return;
      _showSaveSuccess(provider);
      _goBack();
    }
  }

  Future<void> _showParticipantPicker(List<SharedMember> participants) async {
    FocusScope.of(context).unfocus();
    if (participants.isEmpty) return;

    final selected = await showAarastBottomSheet<SharedMember>(
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
                const CreateTaskSheetHandle(),
                const SizedBox(height: 20),
                const AarastSectionHeader(
                  title: 'اختيار مسؤول من المشاركين',
                  icon: LucideIcons.users,
                ),
                const SizedBox(height: 12),
                for (final member in participants) ...[
                  CreateTaskParticipantRow(
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
    _scheduleDraft();
  }

  void _handleResponsibleDraft(ContactPhoneDraft draft) {
    setState(() {
      _responsibleSource = draft.source;
      if (draft.source != ContactPhoneSource.planContact) {
        _clearSelectedParticipant(updateState: false);
      }
    });
    _scheduleDraft();
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
      _scheduleDraft();
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
    if (value.isEmpty || isSelfTaskLabel(value)) return null;
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
