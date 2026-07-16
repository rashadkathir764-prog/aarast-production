import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../wedding_plans/models/wedding_plan.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../providers/marketplace_provider.dart';

class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({
    required this.providerId,
    this.initialServiceId,
    this.initialBudgetIntent,
    super.key,
  });

  final String providerId;
  final String? initialServiceId;
  final ProviderBudgetMatchIntent? initialBudgetIntent;

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _guestCountController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _messageController = TextEditingController();

  String? _weddingPlanId;
  String? _serviceId;
  String? _cityId;
  DateTime? _eventDate;
  WeddingLocationDraft? _eventLocation;
  bool _didApplyInitialPlanContext = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initialServiceId;
    _prefillBudgetIntent(widget.initialBudgetIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final marketplace = context.read<ProviderMarketplaceProvider>();
      marketplace.clearError();
      WeddingPlansProvider? plans;
      GuestOnboardingStorage? guestStorage;
      try {
        plans = context.read<WeddingPlansProvider>();
      } on ProviderNotFoundException {
        plans = null;
      }
      try {
        guestStorage = context.read<GuestOnboardingStorage>();
      } on ProviderNotFoundException {
        guestStorage = null;
      }
      marketplace.loadProviderDetails(widget.providerId);
      final hasAccount =
          AppFeatureFlags.devBypassLoginGatesForUxExploration ||
          await AuthActionGuard.hasAccount(context);
      await marketplace.loadReferenceData();
      if (!mounted) return;
      if (hasAccount) {
        await plans?.loadActiveWeddingPlan();
        await plans?.loadMyWeddingPlans();
      } else {
        await _loadGuestLocationContext(guestStorage);
      }
    });
  }

  void _prefillBudgetIntent(ProviderBudgetMatchIntent? intent) {
    if (intent == null || !intent.hasBudget) return;
    _budgetMinController.text = intent.requestMin!.round().toString();
    _budgetMaxController.text = intent.requestMax!.round().toString();
    if (_messageController.text.trim().isEmpty) {
      _messageController.text =
          'ميزانية بند ${intent.budgetCategoryName}: ${intent.allocatedValue.round()}. أريد عرضاً مناسباً لهذا النطاق.';
    }
  }

  @override
  void dispose() {
    _guestCountController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final plans = context.watch<WeddingPlansProvider>();
    final currencyLabel = _selectedCurrencyLabel(plans);
    final auth = context.watch<AuthController>();
    final provider = marketplace.providerDetails(widget.providerId);
    final services = marketplace.servicesFor(widget.providerId);
    final submitError =
        marketplace.quoteSubmitErrorMessage ?? marketplace.errorMessage;
    _scheduleInitialPlanContext(plans, marketplace);

    return AarastPageScaffold(
      title: 'طلب عرض سعر',
      subtitle: provider == null
          ? 'حدد احتياجك للمورد'
          : 'إلى ${provider.businessName}',
      actions: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
      resizeToAvoidBottomInset: true,
      child:
          auth.status == AuthStatus.unauthenticated &&
              !AppFeatureFlags.devBypassLoginGatesForUxExploration
          ? _QuoteAuthRequired(onLogin: () => context.go(AppRouter.login))
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  _QuoteRequestHero(provider: provider),
                  const SizedBox(height: 18),
                  AarastCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _weddingPlanId,
                          decoration: const InputDecoration(
                            labelText: 'خطة الزفاف',
                            prefixIcon: Icon(LucideIcons.calendarDays),
                          ),
                          items: plans.plans
                              .map(
                                (plan) => DropdownMenuItem(
                                  value: plan.id,
                                  child: Text(plan.title),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              _selectWeddingPlan(value, plans, marketplace),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _safeSelectedService(services),
                          decoration: const InputDecoration(
                            labelText: 'الخدمة',
                            prefixIcon: Icon(LucideIcons.wand),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('حسب اقتراح المورد'),
                            ),
                            for (final service in services)
                              DropdownMenuItem(
                                value: service.id,
                                child: Text(service.title),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _serviceId = value;
                          }),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _cityId,
                          decoration: const InputDecoration(
                            labelText: 'المدينة',
                            prefixIcon: Icon(LucideIcons.mapPin),
                          ),
                          items: marketplace.cities
                              .map(
                                (city) => DropdownMenuItem(
                                  value: city.id,
                                  child: Text(city.nameAr),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            _cityId = value;
                          }),
                        ),
                        const SizedBox(height: 14),
                        _QuoteLocationContext(location: _eventLocation),
                        const SizedBox(height: 14),
                        _QuoteContactContext(phone: auth.user?.phone),
                        const SizedBox(height: 14),
                        _DateField(value: _eventDate, onTap: _pickDate),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _guestCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الضيوف المتوقع',
                            prefixIcon: Icon(LucideIcons.users),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMinController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'أقل ميزانية',
                                  suffixText: currencyLabel,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMaxController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'أعلى ميزانية',
                                  suffixText: currencyLabel,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          maxLength: 250,
                          decoration: const InputDecoration(
                            labelText: 'رسالة للمورد',
                            hintText:
                                'اكتب تفاصيل التاريخ، الموقع، والاحتياج...',
                            prefixIcon: Icon(LucideIcons.fileText),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 8) {
                              return 'اكتب تفاصيل قصيرة ليفهم المورد طلبك';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (submitError != null) ...[
                    Text(
                      submitError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AarastButton(
                    label: 'إرسال الطلب',
                    icon: LucideIcons.send,
                    isLoading: marketplace.isSubmitting,
                    onPressed: marketplace.isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String? _safeSelectedService(List<MarketplaceService> services) {
    if (_serviceId == null) return null;
    return services.any((service) => service.id == _serviceId)
        ? _serviceId
        : null;
  }

  String _selectedCurrencyLabel(WeddingPlansProvider plans) {
    final planId = _weddingPlanId;
    if (planId != null) {
      final plan = _findWeddingPlan(plans.plans, planId);
      if (plan != null) return currencyLabelAr(plan.currency);
    }
    final activeCurrency = plans.activePlan?.currency;
    final selectedCurrency = plans.selectedPlan?.currency;
    return currencyLabelAr(activeCurrency ?? selectedCurrency);
  }

  Future<void> _loadGuestLocationContext(
    GuestOnboardingStorage? guestStorage,
  ) async {
    if (guestStorage == null) return;
    final guestPlan = await guestStorage.loadGuestPlan();
    if (!mounted || guestPlan == null) return;
    final location = guestPlan.weddingLocation;
    if (!location.hasAnyLocation && guestPlan.weddingDate == null) return;
    setState(() {
      if (location.hasAnyLocation) {
        _eventLocation = location;
      }
      _eventDate ??= guestPlan.weddingDate;
    });
    _prefillLocationMessage(location);
  }

  void _scheduleInitialPlanContext(
    WeddingPlansProvider plans,
    ProviderMarketplaceProvider marketplace,
  ) {
    if (_didApplyInitialPlanContext) return;
    final activePlan = plans.activePlan;
    if (activePlan == null) return;
    _didApplyInitialPlanContext = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = activePlan.weddingLocation;
      final matchingCityId = _matchingCityId(marketplace, location);
      setState(() {
        _weddingPlanId ??= activePlan.id;
        _eventDate ??= activePlan.weddingDate;
        if (location.hasAnyLocation) {
          _eventLocation ??= location;
        }
        _cityId ??= matchingCityId;
      });
      _prefillLocationMessage(location);
    });
  }

  void _selectWeddingPlan(
    String? planId,
    WeddingPlansProvider plans,
    ProviderMarketplaceProvider marketplace,
  ) {
    if (planId == null) {
      setState(() => _weddingPlanId = null);
      return;
    }

    final activePlan = plans.activePlan;
    WeddingLocationDraft location = const WeddingLocationDraft();
    DateTime? eventDate;

    if (activePlan?.id == planId) {
      location = activePlan!.weddingLocation;
      eventDate = activePlan.weddingDate;
    } else {
      final selectedPlan = _findWeddingPlan(plans.plans, planId);
      if (selectedPlan != null) {
        location = selectedPlan.weddingLocation;
        eventDate = selectedPlan.weddingDate;
      }
    }

    final matchingCityId = _matchingCityId(marketplace, location);
    setState(() {
      _weddingPlanId = planId;
      if (eventDate != null) {
        _eventDate = eventDate;
      }
      _eventLocation = location.hasAnyLocation ? location : null;
      if (matchingCityId != null) {
        _cityId = matchingCityId;
      }
    });
    _prefillLocationMessage(location);
  }

  WeddingPlan? _findWeddingPlan(List<WeddingPlan> plans, String planId) {
    for (final plan in plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  String? _matchingCityId(
    ProviderMarketplaceProvider marketplace,
    WeddingLocationDraft location,
  ) {
    final candidates = <String>[
      if (location.cityOrDistrict?.trim().isNotEmpty == true)
        location.cityOrDistrict!.trim(),
      if (location.governorate?.trim().isNotEmpty == true)
        location.governorate!.trim(),
    ];
    if (candidates.isEmpty) return null;

    for (final city in marketplace.cities) {
      final cityName = city.nameAr.trim();
      if (candidates.any((candidate) => candidate == cityName)) {
        return city.id;
      }
    }
    return null;
  }

  void _prefillLocationMessage(WeddingLocationDraft location) {
    final label = location.mediumLabel ?? location.shortLabel;
    if (label == null || _messageController.text.trim().isNotEmpty) return;
    _messageController.text =
        'موقع الزفاف: $label\nأحتاج عرض سعر مناسب لتفاصيل المناسبة.';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(
      context,
      message: AuthActionGuard.quoteSubmitMessage,
    )) {
      return;
    }
    if (!mounted) return;

    final guestCount = int.tryParse(_guestCountController.text.trim());
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final success = await marketplace.createQuoteRequest(
      providerId: widget.providerId,
      weddingPlanId: _weddingPlanId,
      serviceId: _serviceId,
      eventDate: _eventDate,
      location: _quoteLocationPayload(marketplace),
      cityId: _cityId,
      guestCount: guestCount,
      contactName: context.read<AuthController>().user?.name,
      contactPhone: context.read<AuthController>().user?.phone,
      budgetMin: _budgetMinController.text,
      budgetMax: _budgetMaxController.text,
      message: _messageController.text,
    );

    if (!mounted) return;
    if (success) {
      AarastToast.showSuccess(context, 'تم إرسال طلب عرض السعر بنجاح');
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRouter.providerDetails(widget.providerId));
      }
    }
  }

  Map<String, dynamic>? _quoteLocationPayload(
    ProviderMarketplaceProvider marketplace,
  ) {
    final location = _eventLocation;
    final selectedCityName = _selectedCityName(marketplace);

    if (location == null || !location.hasAnyLocation) {
      return selectedCityName == null ? null : {'city': selectedCityName};
    }

    if (location.hasRequiredLocation) {
      return location.toJson();
    }

    final city = _cleanText(location.cityOrDistrict) ?? selectedCityName;
    if (city != null) {
      return {'city': city};
    }

    // Send an explicit empty object so the backend does not fall back to a
    // previously stored partial structured location for the selected plan.
    return const <String, dynamic>{};
  }

  String? _selectedCityName(ProviderMarketplaceProvider marketplace) {
    final id = _cityId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final city in marketplace.cities) {
      if (city.id == id) return _cleanText(city.nameAr);
    }
    return null;
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _QuoteLocationContext extends StatelessWidget {
  const _QuoteLocationContext({required this.location});

  final WeddingLocationDraft? location;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location?.hasAnyLocation == true;
    final title = hasLocation ? 'موقع الزفاف' : 'موقع الزفاف غير مكتمل';
    final message = hasLocation
        ? 'سيظهر موقع الزفاف في تفاصيل الطلب حتى يقدّر المورد السعر بدقة. يمكنك تعديل الرسالة قبل الإرسال.'
        : 'أضف موقع الزفاف حتى يفهم المورد مكان المناسبة قبل تسعير الطلب.';
    final label = location?.fullLabel ?? location?.mediumLabel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasLocation ? AppTheme.success.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: hasLocation
              ? AppTheme.success.withValues(alpha: 0.22)
              : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasLocation ? LucideIcons.mapPin : LucideIcons.mapPin,
            color: hasLocation ? AppTheme.success : AppTheme.burgundy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.burgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
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

class _QuoteContactContext extends StatelessWidget {
  const _QuoteContactContext({this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) {
    final displayPhone = PhoneNumberUtils.display(phone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.phoneCall, color: AppTheme.burgundy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رقم التواصل',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                if (displayPhone != null)
                  AarastPhoneText(
                    phone: displayPhone,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  )
                else
                  const Text(
                    'سيُستخدم رقم الحساب عند إرسال الطلب بعد تسجيل الدخول.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
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

class _QuoteAuthRequired extends StatelessWidget {
  const _QuoteAuthRequired({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        AarastEmptyState(
          icon: LucideIcons.lock,
          title: 'تسجيل الدخول مطلوب',
          message: 'سجّل الدخول أولاً لإرسال طلب عرض سعر للمزود.',
          action: FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(LucideIcons.logIn),
            label: const Text('تسجيل الدخول'),
          ),
        ),
      ],
    );
  }
}

class _QuoteRequestHero extends StatelessWidget {
  const _QuoteRequestHero({required this.provider});

  final MarketplaceProvider? provider;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.surface,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.burgundySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              LucideIcons.messageCircle,
              color: AppTheme.burgundy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider == null
                  ? 'أرسل طلبًا واضحًا وسيصل للمورد عند توفر البيانات.'
                  : 'اكتب التفاصيل وسيتم إرسالها إلى ${provider!.businessName} ضمن طلبات عروض الأسعار.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'تاريخ المناسبة',
          prefixIcon: Icon(LucideIcons.calendar),
        ),
        child: Text(
          value == null
              ? 'اختر التاريخ'
              : '${value!.day}/${value!.month}/${value!.year}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: value == null ? AppTheme.muted : AppTheme.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
