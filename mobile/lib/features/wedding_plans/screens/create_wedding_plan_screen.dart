import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../account_contexts/models/account_context.dart';
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
  final _currencyController = TextEditingController(
    text: currencyLabelAr(defaultCurrencyCode),
  );
  final _governorateController = TextEditingController();
  final _cityOrDistrictController = TextEditingController();
  final _areaOrNeighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _detailedAddressController = TextEditingController();

  DateTime? _weddingDate;
  bool _showOptionalAddress = false;

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
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تاريخ الزفاف',
                    icon: LucideIcons.calendarDays,
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
      setState(() => _weddingDate = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final textTheme = Theme.of(context).textTheme;

    return AarastPageScaffold(
      title: 'إنشاء خطة زفاف',
      subtitle: 'التفاصيل الأساسية فقط — كل شيء قابل للتعديل لاحقًا.',
      showBack: true,
      onBack: _goBack,
      maxWidth: 480,
      resizeToAvoidBottomInset: true,
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
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
                      prefixIcon: Icon(LucideIcons.list),
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
                    areaOrNeighborhoodController: _areaOrNeighborhoodController,
                    streetController: _streetController,
                    detailedAddressController: _detailedAddressController,
                    onChanged: () => setState(() {}),
                    showOptionalDetails: _showOptionalAddress,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _showOptionalAddress = !_showOptionalAddress,
                      ),
                      icon: Icon(
                        _showOptionalAddress
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 17,
                      ),
                      label: const Text('تفاصيل العنوان الاختيارية'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SelectorField(
                    label: 'تاريخ الزفاف',
                    value: _weddingDate == null
                        ? 'اختر التاريخ'
                        : _formatDate(_weddingDate!),
                    icon: LucideIcons.calendarDays,
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الميزانية التقديرية',
                            hintText: '2,500,000',
                            prefixIcon: Icon(LucideIcons.wallet),
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
                      icon: LucideIcons.alertCircle,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AarastButton(
              label: 'إنشاء الخطة',
              icon: LucideIcons.chevronLeft,
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
            const SizedBox(height: 24),
          ],
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
    final location = _locationDraft;
    if (!location.hasRequiredLocation) {
      AarastToast.showError(
        context,
        'حدد المحافظة والمدينة أو المديرية قبل إنشاء الخطة.',
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
      currency: currencyCodeFromDisplayInput(_currencyController.text),
    );

    if (plan != null && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        AarastToast.showInfo(context, notice);
      }
      final accountContexts = context.read<AccountContextController>();
      await accountContexts.refresh();
      if (!mounted) return;
      final matchingContexts = accountContexts.contexts
          .where(
            (candidate) =>
                candidate.isPlan &&
                candidate.isAvailable &&
                candidate.role == AccountContextRole.owner &&
                candidate.weddingPlanId == plan.id,
          )
          .toList(growable: false);
      final target = matchingContexts.isEmpty ? null : matchingContexts.first;
      final selected =
          target != null && await accountContexts.select(target.contextKey);
      if (!mounted) return;
      if (!selected) {
        AarastToast.showError(
          context,
          accountContexts.errorMessage ??
              'تعذر تفعيل مسار الخطة الجديدة. ارجع إلى اختيار المسار وحاول مرة أخرى.',
        );
        return;
      }
      context.go(AppRouter.weddingPlanDashboard(plan.id));
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
            const Icon(LucideIcons.chevronDown, color: AppTheme.muted),
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

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
