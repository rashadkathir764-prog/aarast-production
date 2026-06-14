import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/wedding_plans_provider.dart';

class CreateWeddingPlanScreen extends StatefulWidget {
  const CreateWeddingPlanScreen({super.key});

  @override
  State<CreateWeddingPlanScreen> createState() =>
      _CreateWeddingPlanScreenState();
}

class _CreateWeddingPlanScreenState extends State<CreateWeddingPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _budgetController = TextEditingController();
  final _currencyController = TextEditingController(text: 'YER');

  String? _selectedCity;
  DateTime? _weddingDate;

  static const _cities = [
    'صنعاء',
    'عدن',
    'تعز',
    'الحديدة',
    'إب',
    'المكلا',
    'ذمار',
    'غير ذلك',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _showCityPicker() async {
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
                    title: 'اختاري مدينة الزفاف',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),
                  for (final city in _cities)
                    _PickerRow(
                      label: city,
                      selected: city == _selectedCity,
                      onTap: () => Navigator.of(sheetContext).pop(city),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _selectedCity = selected);
    }
  }

  Future<void> _showCalendarPicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = _weddingDate ?? now;

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
                    title: 'تاريخ الزفاف',
                    icon: Icons.calendar_month_rounded,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppTheme.dMaroon,
                        onPrimary: Colors.white,
                        surface: AppTheme.dCard2,
                        onSurface: AppTheme.dInk,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 10),
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

    if (selected != null) {
      setState(() => _weddingDate = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final textTheme = Theme.of(context).textTheme;

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
                              'إنشاء خطة زفاف',
                              style: textTheme.titleLarge?.copyWith(
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
                            const _CreatePlanHero(),
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
                                      labelText: 'عنوان الخطة',
                                      hintText: 'مثال: حفلتنا الكبيرة',
                                      prefixIcon: Icon(Icons.list_alt_rounded),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'عنوان الخطة مطلوب';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _SelectorField(
                                    label: 'المدينة (اختياري)',
                                    value: _selectedCity ?? 'اختاري المدينة',
                                    icon: Icons.location_on_outlined,
                                    selected: _selectedCity != null,
                                    onTap: _showCityPicker,
                                  ),
                                  const SizedBox(height: 14),
                                  _SelectorField(
                                    label: 'تاريخ الزفاف',
                                    value: _weddingDate == null
                                        ? 'اختاري التاريخ'
                                        : _formatDate(_weddingDate!),
                                    icon: Icons.calendar_month_rounded,
                                    selected: _weddingDate != null,
                                    onTap: _showCalendarPicker,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _budgetController,
                                          textAlign: TextAlign.right,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: const InputDecoration(
                                            labelText: 'الميزانية التقديرية',
                                            hintText: '2,500,000',
                                            prefixIcon: Icon(
                                              Icons
                                                  .account_balance_wallet_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 92,
                                        child: TextFormField(
                                          controller: _currencyController,
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(
                                            labelText: 'العملة',
                                          ),
                                        ),
                                      ),
                                    ],
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
                            const SizedBox(height: 16),
                            _PlanPreviewCard(
                              title: _titleController.text.trim().isEmpty
                                  ? 'خطة زفافنا'
                                  : _titleController.text.trim(),
                              city: _selectedCity ?? 'غير محدد',
                              budget: _budgetController.text.trim().isEmpty
                                  ? '0'
                                  : _budgetController.text.trim(),
                            ),
                            const SizedBox(height: 18),
                            PrimaryActionButton(
                              label: 'إنشاء الخطة',
                              icon: Icons.chevron_left_rounded,
                              isLoading: provider.isSubmitting,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'يمكنك تعديل الخطة في أي وقت.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.dInkSoft,
                                fontWeight: FontWeight.w700,
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
    context.go(AppRouter.home);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<WeddingPlansProvider>();
    final budget = _budgetController.text.trim();
    final plan = await provider.createWeddingPlan(
      title: _titleController.text.trim(),
      city: _selectedCity,
      weddingDate: _weddingDate,
      estimatedBudget: budget.isEmpty ? null : budget,
      currency: _currencyController.text.trim().isEmpty
          ? 'YER'
          : _currencyController.text.trim(),
    );

    if (plan != null && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
      _goBack();
    }
  }
}

class _CreatePlanHero extends StatelessWidget {
  const _CreatePlanHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.dGold2.withAlpha(180)),
            ),
            child: CustomPaint(painter: _RingsPainter()),
          ),
          const SizedBox(height: 18),
          Text(
            'ابدئي بخطة واضحة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'دعينا نجهز تفاصيل زفافك خطوة بخطوة بكل سهولة.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withAlpha(220),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPreviewCard extends StatelessWidget {
  const _PlanPreviewCard({
    required this.title,
    required this.city,
    required this.budget,
  });

  final String title;
  final String city;
  final String budget;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg.withAlpha(115),
      border: Border.all(color: AppTheme.dMaroon.withAlpha(34)),
      child: Column(
        children: [
          Text(
            'ملخص خطتك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PreviewMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  value: budget,
                  label: 'الميزانية',
                ),
              ),
              Expanded(
                child: _PreviewMetric(
                  icon: Icons.checklist_rounded,
                  value: '0',
                  label: 'المهام',
                ),
              ),
              Expanded(
                child: _PreviewMetric(
                  icon: Icons.location_on_outlined,
                  value: city,
                  label: title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.dMaroon, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.dInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.dMaroon : AppTheme.dLine,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.dMaroon : AppTheme.dGoldDeep),
            const SizedBox(width: 12),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppTheme.dInk : AppTheme.dMuted,
                      fontWeight: FontWeight.w800,
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
            Expanded(
              child: Text(
                label,
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

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    stroke.color = AppTheme.dMaroon;
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.56),
      size.width * 0.16,
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.56),
      size.width * 0.16,
      stroke,
    );

    final heart = Paint()..color = AppTheme.dMaroon;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.31)
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.22,
        size.width * 0.30,
        size.height * 0.36,
        size.width * 0.5,
        size.height * 0.47,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.36,
        size.width * 0.60,
        size.height * 0.22,
        size.width * 0.5,
        size.height * 0.31,
      );
    canvas.drawPath(path, heart);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
