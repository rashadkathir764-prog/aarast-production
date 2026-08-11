import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../account_contexts/models/account_context.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/wedding_plan_creation_form.dart';

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
  final _governorateController = TextEditingController();
  final _cityOrDistrictController = TextEditingController();
  final _areaOrNeighborhoodController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _detailedAddressController = TextEditingController();

  DateTime? _weddingDate;
  String _currency = 'YER';
  bool _showOptionalAddress = false;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _titleController.dispose();
    _budgetController.dispose();
    _governorateController.dispose();
    _cityOrDistrictController.dispose();
    _areaOrNeighborhoodController.dispose();
    _neighborhoodController.dispose();
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
                        primary: AppTheme.brand,
                        onPrimary: Colors.white,
                        surface: AppTheme.surfaceRaised,
                        onSurface: AppTheme.textPrimary,
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
      _draft?.changed();
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
      bottomNavigationBar: AarastV3FormActionBar(
        label: 'إنشاء الخطة',
        icon: LucideIcons.chevronLeft,
        loading: provider.isSubmitting,
        onPressed: _submit,
      ),
      child: WeddingPlanCreationScope(
        formKey: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            WeddingPlanCreationFields(
              titleController: _titleController,
              governorateController: _governorateController,
              cityOrDistrictController: _cityOrDistrictController,
              areaOrNeighborhoodController: _areaOrNeighborhoodController,
              neighborhoodController: _neighborhoodController,
              streetController: _streetController,
              detailedAddressController: _detailedAddressController,
              budgetController: _budgetController,
              currency: _currency,
              weddingDate: _weddingDate,
              showOptionalAddress: _showOptionalAddress,
              onSelectDate: _showCalendarPicker,
              onCurrencyChanged: (value) {
                setState(() => _currency = value);
                _draft?.changed();
              },
              onToggleOptionalAddress: () {
                setState(() => _showOptionalAddress = !_showOptionalAddress);
                _draft?.changed();
              },
              onChanged: () {
                setState(() {});
                _draft?.changed();
              },
              draftStatus: _draft == null
                  ? null
                  : AarastV3DraftStatusLine(status: _draft!.status),
              errorMessage: provider.errorMessage,
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك تعديل الخطة في أي وقت.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
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
      currency: _currency,
    );

    if (plan != null && mounted) {
      await _draft?.clear();
      if (!mounted) return;
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
      AarastFormSuccess.show(context, message: 'تم إنشاء الخطة وتفعيلها.');
      context.go(AppRouter.weddingPlanDashboard(plan.id));
    }
  }

  WeddingLocationDraft get _locationDraft {
    return WeddingLocationDraft.fromLegacyFields(
      governorate: _governorateController.text,
      city: _cityOrDistrictController.text,
      district: _areaOrNeighborhoodController.text,
      neighborhood: _neighborhoodController.text,
      street: _streetController.text,
      addressNote: _detailedAddressController.text,
    );
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'wedding-plan:new',
      fields: {
        'title': _titleController,
        'budget': _budgetController,
        'governorate': _governorateController,
        'city': _cityOrDistrictController,
        'area': _areaOrNeighborhoodController,
        'neighborhood': _neighborhoodController,
        'street': _streetController,
        'address': _detailedAddressController,
      },
      readExtras: () => {
        'weddingDate': _weddingDate?.toIso8601String(),
        'currency': _currency,
        'showOptionalAddress': _showOptionalAddress,
      },
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() {
          _weddingDate = DateTime.tryParse(
            data['weddingDate']?.toString() ?? '',
          );
          final restoredCurrency = data['currency']?.toString();
          if (restoredCurrency == 'YER' ||
              restoredCurrency == 'SAR' ||
              restoredCurrency == 'USD') {
            _currency = restoredCurrency!;
          }
          _showOptionalAddress = data['showOptionalAddress'] == true;
        });
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
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
