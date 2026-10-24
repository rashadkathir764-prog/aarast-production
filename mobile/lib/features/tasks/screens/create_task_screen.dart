import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../sharing/sharing_api.dart' show SharedMember, SharingProvider;
import '../../wedding_plans/wedding_plans_api.dart' show publishTaskPlanPulse;
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../widgets/create_task_components.dart';

part 'create_task_screen_draft.dart';
part 'create_task_screen_privacy.dart';
part 'create_task_screen_who.dart';

/// d02 «مهمة جديدة» and editing a task: what, when and for whom, kept
/// private when the owner wants (w25). The steps live on the task itself
/// (d04), and a category or priority already set is kept as it is.
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherNameController = TextEditingController();
  final _otherPhoneController = TextEditingController();

  _When _when = _When.week;
  DateTime? _pickedDate;
  String _who = _whoMe;
  String _priority = 'MEDIUM';
  String? _category = 'GENERAL';
  String _status = 'TODO';
  String? _assigneeUserId;
  String? _assigneeName;
  String? _assigneePhone;
  String? _assigneeRole;
  ContactPhoneSource _otherSource = ContactPhoneSource.manual;
  bool _isPrivate = false;
  bool _showMore = false;
  String? _titleError;
  String? _otherNameError;
  bool _didPrefill = false, _didRequestMembers = false;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _descriptionController,
      _otherNameController,
      _otherPhoneController,
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
    final currentUserId = context.read<AuthController?>()?.user?.id;
    final task =
        widget.initialTask ??
        _editingTask(context.read<TaskTimelineProvider>());
    if (task != null) {
      _prefillTask(task, currentUserId);
      _showMore = task.hasDescription;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _descriptionController,
      _otherNameController,
      _otherPhoneController,
    ]) {
      controller
        ..removeListener(_handleTextChanged)
        ..dispose();
    }
    _draft?.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    _scheduleDraft();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final members = sharedMembersForPlan(
      context.watch<SharingProvider?>()?.members ?? const <SharedMember>[],
      widget.weddingPlanId,
    );
    final currentUserId = context.watch<AuthController?>()?.user?.id;
    final locked = _keepsPrivate(provider);

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: _isEditMode ? 'تعديل المهمة' : 'مهمة جديدة',
              onBack: _goBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                JourneyTextField(
                  key: const ValueKey('task-title'),
                  label: 'ايش المهمة؟',
                  hint: 'مثلًا: تذوّق الضيافة مع صالح',
                  controller: _titleController,
                  autofocus: !_isEditMode,
                  maxLength: 200,
                  errorText: _titleError,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _titleError = null),
                ),
                const SizedBox(height: 14),
                _label('متى؟'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (option, label, icon) in const [
                      (_When.week, 'هذا الأسبوع', null),
                      (_When.month, 'هذا الشهر', null),
                      (_When.date, 'تاريخ', LucideIcons.calendarDays),
                      (_When.none, 'بدون موعد', null),
                    ])
                      JourneyChip(
                        key: ValueKey('task-when-${option.name}'),
                        label: option == _When.date && _pickedDate != null
                            ? formatArabicDayMonth(_pickedDate!)
                            : label,
                        icon: icon,
                        selected: _when == option,
                        selectedColor: AarastV3Color.brandAccentStrong,
                        onTap: () => option == _When.date
                            ? _pickDate()
                            : _mutateDraft(() => _when = option),
                      ),
                  ],
                ),
                if (_when == _When.week || _when == _When.month)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'قبل ${formatArabicWeekdayDayMonth(_dueDate!)}',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                CreateTaskResponsibleSection(
                  choices: _whoChoices(provider, members, currentUserId),
                  selected: _who,
                  locked: locked,
                  onSelected: (who) => _mutateDraft(() {
                    _who = who;
                    _otherNameError = null;
                  }),
                  otherNameController: _otherNameController,
                  otherPhoneController: _otherPhoneController,
                  otherNameError: _otherNameError,
                  onDraftChanged: (draft) =>
                      _mutateDraft(() => _otherSource = draft.source),
                  canInvite: _otherPhoneController.text.trim().isNotEmpty,
                  onInvite: _inviteResponsibleAsParticipant,
                ),
                ..._privacySection(provider),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('task-more'),
                    label: _showMore ? 'أقل' : 'أضف ملاحظة',
                    icon: _showMore
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: AarastV3Color.primary,
                    onPressed: () => setState(() => _showMore = !_showMore),
                  ),
                ),
                if (_showMore)
                  JourneyTextField(
                    key: const ValueKey('task-note'),
                    label: 'ملاحظة',
                    hint: 'ايش لازم تتذكر وقت تسويها؟',
                    controller: _descriptionController,
                    maxLength: 1000,
                  ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  JourneyNote(
                    text: provider.errorMessage!,
                    icon: LucideIcons.alertCircle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
                if (_draft != null) ...[
                  const SizedBox(height: 8),
                  AarastV3DraftStatusLine(status: _draft!.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const ValueKey('task-save'),
              label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المهمة',
              background: AarastV3Color.brandAccentStrong,
              expand: true,
              large: true,
              loading: provider.isSubmitting,
              onPressed: provider.isSubmitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: AarastV3Color.textMuted,
      ),
    ),
  );

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _pickedDate != null && !_pickedDate!.isBefore(today)
        ? _pickedDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 1),
      lastDate: today.add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked == null || !mounted) return;
    _mutateDraft(() {
      _pickedDate = picked;
      _when = _When.date;
    });
  }

  void _goBack() => context.popOrGo(AppRouter.tasks(widget.weddingPlanId));

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'اكتب ايش المهمة');
      return;
    }
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<TaskTimelineProvider>();
    final members = sharedMembersForPlan(
      context.read<SharingProvider?>()?.members ?? const <SharedMember>[],
      widget.weddingPlanId,
    );
    final currentUserId = context.read<AuthController?>()?.user?.id;
    final who = _responsibleFor(provider, members, currentUserId);
    if (who == null) return;
    final givenAway =
        (who.assigneeUserId != null && who.assigneeUserId != currentUserId) ||
        who.responsibleName != null;
    if (_keepsPrivate(provider) && givenAway) {
      AarastToast.showError(
        context,
        'المهمة الخاصة تبقى لك وحدك. خلّها لك، أو شاركها مع الخطة أول.',
      );
      return;
    }
    final description = _descriptionController.text.trim();
    final task = _editingTask(provider);
    if (_isEditMode && task == null) {
      AarastToast.showError(context, 'ما قدرنا نفتح المهمة للتعديل');
      return;
    }
    final saved = task != null
        ? await provider.updateTask(
            weddingPlanId: widget.weddingPlanId,
            task: task,
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            dueDate: _dueDate,
            taskCategory: _category,
            assigneeUserId: who.assigneeUserId,
            assigneeName: who.assigneeName,
            assigneePhone: who.assigneePhone,
            assigneeRole: who.assigneeRole,
            responsibleName: who.responsibleName,
            responsiblePhone: who.responsiblePhone,
            responsibleSource: who.responsibleSource,
            status: _status,
            priority: _priority,
          )
        : await provider.createTask(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            dueDate: _dueDate,
            taskCategory: _category,
            assigneeUserId: who.assigneeUserId,
            assigneeName: who.assigneeName,
            assigneePhone: who.assigneePhone,
            assigneeRole: who.assigneeRole,
            responsibleName: who.responsibleName,
            responsiblePhone: who.responsiblePhone,
            responsibleSource: who.responsibleSource,
            status: 'TODO',
            priority: _priority,
            isPrivate: _isPrivate,
          );
    if (!saved || !mounted) return;
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

  Future<void> _inviteResponsibleAsParticipant() async {
    final allowed = await AuthActionGuard.requireAccount(
      context,
      reason: 'دعوة مسؤول المهمة كمشارك في الخطة تحتاج حساباً وصلاحيات مشاركة.',
    );
    if (!allowed || !mounted) return;
    context.push(AppRouter.addSharedMember(widget.weddingPlanId));
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
}
