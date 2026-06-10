import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/routing/app_router.dart';
import '../providers/task_timeline_provider.dart';
import '../../wedding_plans/widgets/new_dashboard_widgets.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'URGENT';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<TaskTimelineProvider>();
    final created = await provider.createTask(
      weddingPlanId: widget.weddingPlanId,
      title: _titleController.text,
      description: _descriptionController.text,
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final theme = Theme.of(context);
    final customTheme = theme.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
    );

    return Theme(
      data: customTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: DashboardUiColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildFormCard(),
                const SizedBox(height: 16),
                _buildAssignCard(),
                const SizedBox(height: 24),
                _buildSaveButton(provider.isSubmitting),
                const SizedBox(height: 24),
                _buildBottomBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left icons
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: DashboardUiColors.borderLight, width: 1.5),
                      ),
                      child: const Icon(Icons.notifications_none_rounded, color: DashboardUiColors.primaryMaroon, size: 24),
                    ),
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: DashboardUiColors.primaryMaroon, shape: BoxShape.circle),
                        child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: DashboardUiColors.borderLight, width: 1.5),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: DashboardUiColors.heroGold, size: 24),
                ),
              ],
            ),
            // Right back button
            GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRouter.tasks(widget.weddingPlanId));
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DashboardUiColors.borderLight),
                ),
                child: const Icon(Icons.chevron_right, color: DashboardUiColors.textDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Centered title
        const Text(
          'إضافة مهمة',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: DashboardUiColors.primaryMaroon,
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'نظمي كل تفصيل بخطوة مدروسة ',
              style: TextStyle(
                fontSize: 12,
                color: DashboardUiColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('✨', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashboardUiColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('عنوان المهمة', Icons.edit_square),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'اكتبي عنوان المهمة',
                hintStyle: const TextStyle(color: DashboardUiColors.textLightGray, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: DashboardUiColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: DashboardUiColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: DashboardUiColors.primaryMaroon),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'عنوان المهمة مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('الفئة', Icons.grid_view),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DashboardUiColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: DashboardUiColors.textLightGray),
                  hint: const Text('اختاري فئة المهمة', style: TextStyle(color: DashboardUiColors.textLightGray, fontSize: 13)),
                  items: const [],
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('التاريخ', Icons.calendar_today),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickDueDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DashboardUiColors.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dueDate == null ? 'اختري التاريخ' : _formatDate(_dueDate!),
                                style: TextStyle(
                                  color: _dueDate == null ? DashboardUiColors.textLightGray : DashboardUiColors.textDark,
                                  fontSize: 13,
                                ),
                              ),
                              const Icon(Icons.calendar_today_outlined, color: DashboardUiColors.textLightGray, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('الوقت (اختياري)', Icons.access_time),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DashboardUiColors.borderLight),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'اختري الوقت',
                              style: TextStyle(
                                color: DashboardUiColors.textLightGray,
                                fontSize: 13,
                              ),
                            ),
                            Icon(Icons.access_time, color: DashboardUiColors.textLightGray, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('أولوية المهمة', Icons.star_border),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPriorityChip(
                  label: 'منخفضة',
                  icon: Icons.energy_savings_leaf_outlined,
                  iconColor: DashboardUiColors.iconGreen,
                  value: 'LOW',
                ),
                _buildPriorityChip(
                  label: 'متوسطة',
                  icon: Icons.drag_handle,
                  iconColor: DashboardUiColors.iconOrange,
                  value: 'MEDIUM',
                ),
                _buildPriorityChip(
                  label: 'عالية',
                  icon: Icons.keyboard_double_arrow_up_rounded,
                  iconColor: DashboardUiColors.iconOrange,
                  value: 'HIGH',
                ),
                _buildPriorityChip(
                  label: 'عاجلة',
                  icon: Icons.bolt_rounded,
                  iconColor: DashboardUiColors.primaryMaroon,
                  value: 'URGENT',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('ملاحظات (اختياري)', Icons.sticky_note_2_outlined),
            const SizedBox(height: 12),
            Stack(
              children: [
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'أضيفي ملاحظات أو تفاصيل مهمة...',
                    hintStyle: const TextStyle(color: DashboardUiColors.textLightGray, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DashboardUiColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DashboardUiColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DashboardUiColors.primaryMaroon),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  right: 16,
                  child: Text(
                    '0 حرف 0/250',
                    style: TextStyle(fontSize: 10, color: DashboardUiColors.textLightGray),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    final isSelected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? DashboardUiColors.primaryMaroon.withAlpha(15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? DashboardUiColors.primaryMaroon : DashboardUiColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? DashboardUiColors.primaryMaroon : DashboardUiColors.textGray,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 14,
                color: isSelected ? DashboardUiColors.primaryMaroon : iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: DashboardUiColors.textDark,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: DashboardUiColors.primaryMaroon),
      ],
    );
  }

  Widget _buildAssignCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashboardUiColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('إسناد المهمة إلى', Icons.people_outline),
          const SizedBox(height: 20),
          _buildAssignRow(
            title: 'خطة معينة',
            subtitle: 'ربط المهمة بخطة زفاف محددة',
            icon: Icons.assignment_outlined,
            iconBg: DashboardUiColors.bgRed,
            iconColor: DashboardUiColors.primaryMaroon,
            actionText: 'اختاري الخطة',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: DashboardUiColors.borderLight),
          ),
          _buildAssignRow(
            title: 'أشخاص مشاركون',
            subtitle: 'اختاري من سيُسند إليه هذه المهمة',
            icon: Icons.group_add_outlined,
            iconBg: DashboardUiColors.bgGreen,
            iconColor: DashboardUiColors.iconGreen,
            actionText: 'تحديد أشخاص',
          ),
        ],
      ),
    );
  }

  Widget _buildAssignRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String actionText,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DashboardUiColors.textDark)),
                  const SizedBox(width: 4),
                  const Text('(اختياري)', style: TextStyle(fontSize: 11, color: DashboardUiColors.textGray)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: DashboardUiColors.textLightGray)),
            ],
          ),
        ),
        Row(
          children: [
            Text(actionText, style: const TextStyle(fontSize: 12, color: DashboardUiColors.textGray, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, color: DashboardUiColors.textLightGray, size: 18),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isSubmitting) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: DashboardUiColors.primaryMaroon,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: isSubmitting ? null : _submit,
      child: isSubmitting
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('حفظ المهمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.event_available_outlined, size: 20, color: Colors.white),
              ],
            ),
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF5F3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashboardUiColors.primaryMaroon.withAlpha(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('نظمي يومك بكل سهولة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DashboardUiColors.primaryMaroon)),
                        SizedBox(width: 6),
                        Icon(Icons.auto_awesome, color: DashboardUiColors.heroGold, size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إضافة المهام تساعدك على ترتيب أعمال زفافك ومتابعة كل التفاصيل في الوقت المناسب.',
                      style: TextStyle(fontSize: 12, color: DashboardUiColors.textGray, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: DashboardUiColors.primaryMaroon.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.edit_calendar_rounded, size: 30, color: DashboardUiColors.primaryMaroon),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: DashboardUiColors.primaryMaroon, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: DashboardUiColors.primaryMaroon.withAlpha(50), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: DashboardUiColors.primaryMaroon.withAlpha(50), shape: BoxShape.circle)),
            ],
          ),
        ],
      ),
    );
  }
}
