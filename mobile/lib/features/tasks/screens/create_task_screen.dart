import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/task_timeline_provider.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'MEDIUM';
  String _category = 'GENERAL';

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showCalendarPicker() {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    DateTime tempDate = _dueDate ?? now;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.dCard.withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withAlpha(30),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                )
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.dLine,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.dPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.calendarClock, color: AppTheme.dMaroon),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'تاريخ استحقاق المهمة',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.dMaroonDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppTheme.dMaroon,
                            onPrimary: Colors.white,
                            surface: Colors.transparent,
                            onSurface: AppTheme.dInk,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: tempDate,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                          onDateChanged: (date) {
                            tempDate = date;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.dMaroon,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _dueDate = tempDate);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'تأكيد التاريخ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPicker() {
    FocusScope.of(context).unfocus();
    final categories = [
      {'id': 'GENERAL', 'label': 'عامة', 'icon': LucideIcons.layoutGrid, 'color': AppTheme.dMuted},
      {'id': 'VENUE', 'label': 'القاعة', 'icon': LucideIcons.building, 'color': AppTheme.dGold},
      {'id': 'CATERING', 'label': 'الضيافة', 'icon': LucideIcons.coffee, 'color': AppTheme.dMaroon},
      {'id': 'ATTIRE', 'label': 'الملابس', 'icon': LucideIcons.shirt, 'color': AppTheme.dPinkBg},
      {'id': 'GUESTS', 'label': 'الضيوف', 'icon': LucideIcons.users, 'color': AppTheme.dBlue},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: AppTheme.dCard.withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.dLine,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.dPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.tags, color: AppTheme.dMaroon),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'فئة المهمة',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.dMaroonDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = category['id'] == _category;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _category = category['id'] as String);
                                  Navigator.pop(sheetContext);
                                },
                                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected ? AppTheme.dMaroon : AppTheme.dLine,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                    color: isSelected ? AppTheme.dPinkBg.withAlpha(100) : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(category['icon'] as IconData, color: isSelected ? AppTheme.dMaroon : category['color'] as Color),
                                      const SizedBox(width: 16),
                                      Text(
                                        category['label'] as String,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                          color: isSelected ? AppTheme.dMaroonDeep : AppTheme.dInk,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        const Icon(LucideIcons.checkCircle2, color: AppTheme.dMaroon),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dMaroon.withAlpha(15),
                ),
              ),
            ),

            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.tasks(widget.weddingPlanId));
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.dCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.dLine),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.dMaroon),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'إضافة مهمة',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAnimatedField(
                            0,
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dPinkBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.dLine),
                                  ),
                                  child: const Icon(LucideIcons.listTodo, color: AppTheme.dMaroon, size: 36),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'نظمي كل تفصيل بخطوة مدروسة ✨',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),

                          _buildAnimatedField(
                            1,
                            TextFormField(
                              controller: _titleController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                labelText: 'عنوان المهمة',
                                hintText: 'مثال: حجز قاعة الأفراح',
                                prefixIcon: const Icon(LucideIcons.edit3),
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'عنوان المهمة مطلوب';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 20),

                          _buildAnimatedField(
                            2,
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showCategoryPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dCard,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        border: Border.all(color: AppTheme.dLine),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.grid, color: AppTheme.dMuted),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'الفئة',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.dInkSoft,
                                                  ),
                                                ),
                                                Text(
                                                  _categoryLabel(_category),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.dInk,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(LucideIcons.chevronDown, color: AppTheme.dMuted, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showCalendarPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dCard,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        border: Border.all(
                                          color: _dueDate != null ? AppTheme.dMaroon : AppTheme.dLine,
                                          width: _dueDate != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.calendarDays, color: _dueDate != null ? AppTheme.dMaroon : AppTheme.dMuted),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (_dueDate != null)
                                                  Text(
                                                    'التاريخ',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.dInkSoft,
                                                    ),
                                                  ),
                                                Text(
                                                  _dueDate == null ? 'التاريخ (اختياري)' : '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}',
                                                  style: TextStyle(
                                                    fontWeight: _dueDate != null ? FontWeight.w800 : FontWeight.w600,
                                                    color: _dueDate != null ? AppTheme.dInk : AppTheme.dMuted,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          _buildAnimatedField(
                            3,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'أولوية المهمة',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.dInk,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildPriorityChip('LOW', 'عادية', AppTheme.dBlue),
                                    _buildPriorityChip('MEDIUM', 'متوسطة', AppTheme.warning),
                                    _buildPriorityChip('HIGH', 'عاجلة', AppTheme.danger),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          _buildAnimatedField(
                            4,
                            TextFormField(
                              controller: _descriptionController,
                              textAlign: TextAlign.right,
                              maxLines: 4,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'تفاصيل المهمة (اختياري)',
                                alignLabelWithHint: true,
                                hintText: 'أضيفي أي ملاحظات أو تفاصيل تخص هذه المهمة...',
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          _buildAnimatedField(
                            5,
                            PrimaryActionButton(
                              label: 'حفظ المهمة',
                              isLoading: provider.isSubmitting,
                              onPressed: _submit,
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? color : AppTheme.dLine,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(LucideIcons.star, color: color, size: 14),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? color : AppTheme.dMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, childWidget) {
        final delay = 0.1 + (index * 0.1);
        final value = (_animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  String _categoryLabel(String id) {
    switch (id) {
      case 'GENERAL': return 'عامة';
      case 'VENUE': return 'القاعة';
      case 'CATERING': return 'الضيافة';
      case 'ATTIRE': return 'الملابس';
      case 'GUESTS': return 'الضيوف';
      default: return 'عامة';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<TaskTimelineProvider>();
    final created = await provider.createTask(
      weddingPlanId: widget.weddingPlanId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      status: 'TODO',
      priority: _priority,
    );

    if (!mounted) {
      return;
    }

    if (created) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.tasks(widget.weddingPlanId));
      }
    }
  }
}
