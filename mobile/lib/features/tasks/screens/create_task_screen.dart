import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';

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

  DateTime? _dueDate;
  String _priority = 'MEDIUM';
  String _category = 'GENERAL';
  String _status = 'TODO';
  bool _didPrefill = false;

  static const _categories = [
    _TaskCategory('GENERAL', 'عامة', Icons.dashboard_customize_outlined),
    _TaskCategory('VENUE', 'القاعة', Icons.apartment_rounded),
    _TaskCategory('CATERING', 'الضيافة', Icons.room_service_outlined),
    _TaskCategory('ATTIRE', 'الملابس', Icons.checkroom_outlined),
    _TaskCategory('GUESTS', 'الضيوف', Icons.groups_outlined),
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
    if (!_isEditMode || _didPrefill) return;

    final taskId = widget.taskId;
    if (taskId == null) return;

    final provider = context.read<TaskTimelineProvider>();
    for (final task in provider.tasks) {
      if (task.id == taskId) {
        _prefillTask(task);
        return;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
                    icon: Icons.event_available_rounded,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.dMaroon,
                        onPrimary: Colors.white,
                        surface: AppTheme.dCard2,
                        onSurface: AppTheme.dInk,
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
                  PrimaryActionButton(
                    label: 'تأكيد التاريخ',
                    icon: Icons.check_rounded,
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
                    icon: Icons.sell_outlined,
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
    final category = _categories.firstWhere((item) => item.id == _category);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            tooltip: 'رجوع',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isEditMode ? 'تعديل المهمة' : 'إضافة مهمة',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.dMaroonDeep,
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
                            const SizedBox(height: 18),
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
                                      prefixIcon: Icon(Icons.edit_note_rounded),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
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
                                            ? 'اختياري'
                                            : _formatDate(_dueDate!),
                                        icon: Icons.calendar_month_rounded,
                                        selected: _dueDate != null,
                                        onTap: _showCalendarPicker,
                                      );

                                      if (constraints.maxWidth < 330) {
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
                                  const SizedBox(height: 18),
                                  const Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      'أولوية المهمة',
                                      style: TextStyle(
                                        color: AppTheme.dInk,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _PriorityChip(
                                        label: 'منخفضة',
                                        icon: Icons.eco_outlined,
                                        color: AppTheme.dGreen,
                                        selected: _priority == 'LOW',
                                        onTap: () {
                                          setState(() => _priority = 'LOW');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _PriorityChip(
                                        label: 'متوسطة',
                                        icon: Icons.drag_handle_rounded,
                                        color: AppTheme.dGoldDeep,
                                        selected: _priority == 'MEDIUM',
                                        onTap: () {
                                          setState(() => _priority = 'MEDIUM');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _PriorityChip(
                                        label: 'عاجلة',
                                        icon: Icons.bolt_rounded,
                                        color: AppTheme.danger,
                                        selected: _priority == 'HIGH',
                                        onTap: () {
                                          setState(() => _priority = 'HIGH');
                                        },
                                      ),
                                    ],
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
                                      icon: Icons.error_outline_rounded,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            PrimaryActionButton(
                              label: _isEditMode
                                  ? 'حفظ التعديلات'
                                  : 'حفظ المهمة',
                              icon: _isEditMode
                                  ? Icons.save_outlined
                                  : Icons.event_available_rounded,
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
            ),
          ),
        ),
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
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(context)) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<TaskTimelineProvider>();
    final description = _descriptionController.text.trim();
    final normalizedDescription = description.isEmpty ? null : description;
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
                status: _status,
                priority: _priority,
              )
        : await provider.createTask(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            description: normalizedDescription,
            dueDate: _dueDate,
            taskCategory: _category,
            status: 'TODO',
            priority: _priority,
          );

    if (_isEditMode && task == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح المهمة للتعديل')));
      return;
    }

    if (saved && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
      _goBack();
    }
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
      color: AppTheme.dPinkBg.withAlpha(120),
      border: Border.all(color: AppTheme.dMaroon.withAlpha(35)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.dCard2,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: AppTheme.dMaroon,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظمي كل تفصيل بخطوة مدروسة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المهام الواضحة تجعل يومك أسهل وأهدأ.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
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
          color: AppTheme.dCard2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.dMaroon : AppTheme.dLine,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.dMaroon : AppTheme.dGoldDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.dInkSoft),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.dMuted,
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
            color: selected ? color.withAlpha(25) : AppTheme.dCard2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppTheme.dLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppTheme.dMuted, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.dMuted,
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
        color: selected ? AppTheme.dPinkBg : AppTheme.dCard2,
        border: Border.all(color: selected ? AppTheme.dMaroon : AppTheme.dLine),
        onTap: onTap,
        child: Row(
          children: [
            Icon(category.icon, color: AppTheme.dMaroon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.dMaroon : AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.dMaroon),
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
          color: AppTheme.dLine,
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
