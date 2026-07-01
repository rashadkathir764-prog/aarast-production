import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../onboarding/widgets/location_picker_section.dart';
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
  final _governorateController = TextEditingController();
  final _cityOrDistrictController = TextEditingController();
  final _areaOrNeighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _detailedAddressController = TextEditingController();

  DateTime? _weddingDate;

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    _governorateController.dispose();
    _cityOrDistrictController.dispose();
    _areaOrNeighborhoodController.dispose();
    _streetController.dispose();
    _detailedAddressController.dispose();
    super.dispose();
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
                      lastDate: DateTime(now.year + 10),
                      onDateChanged: (date) => tempDate = date,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AarastButton(
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

    if (selected != null && mounted) {
      setState(() => _weddingDate = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final textTheme = Theme.of(context).textTheme;
    final location = _locationDraft;

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
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'إنشاء خطة زفاف',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDeep,
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
                              if (value == null || value.trim().isEmpty) {
                                return 'عنوان الخطة مطلوب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          LocationPickerSection(
                            governorateController: _governorateController,
                            cityOrDistrictController: _cityOrDistrictController,
                            areaOrNeighborhoodController:
                                _areaOrNeighborhoodController,
                            streetController: _streetController,
                            detailedAddressController:
                                _detailedAddressController,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          _SelectorField(
                            label: 'تاريخ الزفاف',
                            value: _weddingDate == null
                                ? 'اختر التاريخ'
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
                                      Icons.account_balance_wallet_outlined,
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
                      city: location.shortLabel ?? 'غير محدد',
                      budget: _budgetController.text.trim().isEmpty
                          ? '0'
                          : _budgetController.text.trim(),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
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
                        color: AppTheme.muted,
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
    final location = _locationDraft;
    if (!location.hasRequiredLocation) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('حدد المحافظة والمدينة أو المديرية قبل إنشاء الخطة.'),
          ),
        );
      return;
    }

    final provider = context.read<WeddingPlansProvider>();
    final budget = _budgetController.text.trim();
    final plan = await provider.createWeddingPlan(
      title: _titleController.text.trim(),
      city: location.cityOrDistrict,
      location: location.toJson(),
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

  WeddingLocationDraft get _locationDraft {
    return WeddingLocationDraft.fromLegacyFields(
      governorate: _governorateController.text,
      city: _cityOrDistrictController.text,
      district: _areaOrNeighborhoodController.text,
      street: _streetController.text,
      addressNote: _detailedAddressController.text,
    );
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
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold2.withAlpha(180)),
            ),
            child: CustomPaint(painter: _RingsPainter()),
          ),
          const SizedBox(height: 18),
          Text(
            'ابدأ بخطة واضحة',
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
              color: Colors.white.withValues(alpha: 0.6),
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
      color: AppTheme.burgundySoft.withAlpha(115),
      border: Border.all(color: AppTheme.burgundy.withAlpha(34)),
      child: Column(
        children: [
          Text(
            'ملخص خطتك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.burgundyDeep,
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
        Icon(icon, color: AppTheme.burgundy, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.muted,
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 12),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppTheme.ink : AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.muted,
            ),
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

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    stroke.color = AppTheme.burgundy;
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

    final heart = Paint()..color = AppTheme.burgundy;
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
  return formatArabicCompactDate(date);
}
