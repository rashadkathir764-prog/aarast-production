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
import '../../../core/utils/app_clock.dart';
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
    this.handOver = false,
    super.key,
  });

  final String weddingPlanId;
  final String? taskId;
  final WeddingTask? initialTask;

  /// «حوّلها لأحد ثاني»: the same form, titled for it and opened on «لمين؟».
  final bool handOver;

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

  /// Why this form's own save failed. An error left by another action
  /// (a swipe, a delete) is not this form's and does not show here.
  String? _saveError;
  String? _otherNameError;
  bool _didPrefill = false, _didRequestMembers = false;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  /// Where «لمين؟» starts, to open the form on it for [handOver].
  final _whoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.handOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final who = _whoKey.currentContext;
        if (who != null && who.mounted) {
          Scrollable.ensureVisible(who, duration: AarastV3Motion.standard);
        }
      });
    }
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
      _editAsOpened = _editSignature();
    }
  }

  /// RA-MO-202: the task as the edit opened it, to tell a change made.
  String? _editAsOpened;

  /// Saved: leaving says nothing.
  bool _leavingSaved = false;

  String _editSignature() => [
    _titleController.text.trim(),
    _descriptionController.text.trim(),
    _who,
    _when.name,
    _pickedDate?.toIso8601String(),
    _priority,
    _category,
    _status,
    _assigneeUserId,
    _otherNameController.text.trim(),
    _otherPhoneController.text.trim(),
  ].join('|');

  /// An edit (or a hand-over) with changes not saved: the editor has no
  /// draft, so leaving drops them; it asks first (RA-MO-202).
  bool get _hasUnsavedEdit =>
      _isEditMode &&
      !_leavingSaved &&
      _editAsOpened != null &&
      _editSignature() != _editAsOpened;

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

    return PopScope(
      canPop: !_hasUnsavedEdit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_backAsked());
      },
      child: AarastScreenFrame(
        maxWidth: 600,
        backgroundColor: AarastV3Color.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                AarastV3Space.x2,
                AarastV3Space.x2,
                0,
              ),
              child: JourneySubHeader(
                title: widget.handOver
                    ? context.say('لمين تحوّلها؟', 'لمين تحوّلينها؟')
                    : _isEditMode
                    ? 'تعديل المهمة'
                    : 'مهمة جديدة',
                onBack: _backAsked,
              ),
            ),
            Expanded(
              child: ListView(
                padding: AarastV3Density.pageInsets,
                children: [
                  JourneyTextField(
                    key: const ValueKey('task-title'),
                    label: 'ايش المهمة؟',
                    hint: context.say(
                      'مثلًا: تذوّق الضيافة مع صالح',
                      'مثلًا: تذوّق الضيافة مع نورة',
                    ),
                    controller: _titleController,
                    autofocus: !_isEditMode,
                    maxLength: 200,
                    errorText: _titleError,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _titleError = null),
                  ),
                  const SizedBox(height: AarastV3Space.x3),
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
                          selectedColor: context.accent.primary,
                          onTap: () => option == _When.date
                              ? _pickDate()
                              : _mutateDraft(() => _when = option),
                        ),
                    ],
                  ),
                  if (_when == _When.week || _when == _When.month)
                    Padding(
                      padding: const EdgeInsets.only(top: AarastV3Space.x1),
                      child: Text(
                        'قبل ${formatArabicWeekdayDayMonth(_dueDate!)}',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  SizedBox(key: _whoKey, height: AarastV3Space.x4),
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
                  const SizedBox(height: AarastV3Space.x2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: JourneyTextAction(
                      key: const ValueKey('task-more'),
                      label: _showMore
                          ? 'أقل'
                          : context.say('أضف ملاحظة', 'أضيفي ملاحظة'),
                      icon: _showMore
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      color: context.accent.primary,
                      onPressed: () => setState(() => _showMore = !_showMore),
                    ),
                  ),
                  if (_showMore)
                    JourneyTextField(
                      key: const ValueKey('task-note'),
                      label: 'ملاحظة',
                      hint: context.say(
                        'ايش لازم تتذكر وقت تسويها؟',
                        'ايش لازم تتذكرين وقت تسوينها؟',
                      ),
                      controller: _descriptionController,
                      maxLength: 1000,
                    ),
                  if (_saveError != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    JourneyNote(
                      key: const ValueKey('task-save-error'),
                      text: _saveError!,
                      icon: LucideIcons.alertCircle,
                      color: AarastV3Color.danger,
                      soft: AarastV3Color.dangerSoft,
                    ),
                  ],
                  if (_draft != null) ...[
                    const SizedBox(height: AarastV3Space.x2),
                    AarastV3DraftStatusLine(status: _draft!.status),
                  ],
                ],
              ),
            ),
            Padding(
              padding: AarastV3Density.actionInsets,
              child: JourneyButton(
                key: const ValueKey('task-save'),
                label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المهمة',
                background: context.accent.primary,
                expand: true,
                large: true,
                loading: provider.isSubmitting,
                onPressed: provider.isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
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
    final today = DateUtils.dateOnly(appNow());
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

  /// The header's back and the phone's: an unsaved edit asks first.
  Future<void> _backAsked() async {
    if (_hasUnsavedEdit &&
        !await confirmLeaveUnsaved(context, keyPrefix: 'task-edit')) {
      return;
    }
    if (!mounted) return;
    _leavingSaved = true;
    _goBack();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(
        () => _titleError = context.say('اكتب ايش المهمة', 'اكتبي ايش المهمة'),
      );
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
        context.say(
          'المهمة الخاصة تبقى لك وحدك. خلّها لك، أو شاركها مع الخطة أول.',
          'المهمة الخاصة تبقى لك وحدك. خلّيها لك، أو شاركيها مع الخطة أول.',
        ),
      );
      return;
    }
    final description = _descriptionController.text.trim();
    final task = _editingTask(provider);
    if (_isEditMode && task == null) {
      AarastToast.showError(context, 'ما قدرنا نفتح المهمة للتعديل');
      return;
    }
    if (_saveError != null) setState(() => _saveError = null);
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
    if (!mounted) return;
    if (!saved) {
      setState(
        () => _saveError =
            provider.errorMessage ??
            context.say(
              'ما قدرنا نحفظ المهمة. جرّب مرة ثانية.',
              'ما قدرنا نحفظ المهمة. جرّبي مرة ثانية.',
            ),
      );
      return;
    }
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    await _draft?.clear();
    if (!mounted) return;
    _showSaveSuccess(provider);
    _leavingSaved = true;
    _goBack();
  }

  Future<void> _inviteResponsibleAsParticipant() async {
    final allowed = await AuthActionGuard.requireAccount(
      context,
      reason: 'دعوة المسؤول عن المهمة كمشارك في خطتك تحتاج حساب.',
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
