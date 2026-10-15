import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, WeddingLocationDraft;
import '../../wedding_plans/wedding_plans_api.dart' show WeddingPlansProvider;
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

  String? _serviceId;
  String? _cityId;
  DateTime? _eventDate;
  WeddingLocationDraft? _eventLocation;
  bool _didApplyInitialPlanContext = false;
  final Set<String> _routeLaunchesInFlight = <String>{};
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initialServiceId;
    _prefillBudgetIntent(widget.initialBudgetIntent);
    for (final controller in [
      _guestCountController,
      _budgetMinController,
      _budgetMaxController,
      _messageController,
    ]) {
      controller.addListener(_handleTextChanged);
    }
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
        final selected = context
            .read<AccountContextController?>()
            ?.selectedContext;
        final selectedPlanId = selected?.isPlan == true
            ? selected?.weddingPlanId
            : null;
        if (selectedPlanId != null) {
          await plans?.loadWeddingPlan(selectedPlanId);
        }
      } else {
        await _loadGuestLocationContext(guestStorage);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didConfigureDraft) return;
    _didConfigureDraft = true;
    final store = context.read<AarastFormDraftStore?>();
    if (store == null) return;
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final planId = selected?.isPlan == true
        ? selected?.weddingPlanId
        : 'unselected';
    _draft = AarastFormDraftCoordinator(
      store: store,
      scope: 'quote:$planId:${widget.providerId}',
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    _restoreDraft();
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
    _draft?.dispose();
    for (final controller in [
      _guestCountController,
      _budgetMinController,
      _budgetMaxController,
      _messageController,
    ]) {
      controller
        ..removeListener(_handleTextChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final plans = context.watch<WeddingPlansProvider>();
    final selectedContext = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = selectedContext?.isPlan == true
        ? selectedContext?.weddingPlanId
        : null;
    final currencyLabel = _selectedCurrencyLabel(plans, selectedPlanId);
    final auth = context.watch<AuthController>();
    final provider = marketplace.providerDetails(widget.providerId);
    final services = marketplace.servicesFor(widget.providerId);
    final submitError =
        marketplace.quoteSubmitErrorMessage ?? marketplace.errorMessage;
    final requiresAuth =
        auth.status == AuthStatus.unauthenticated &&
        !AppFeatureFlags.devBypassLoginGatesForUxExploration;
    final selectedServiceLabel = _quoteServiceLabel(services);
    _scheduleInitialPlanContext(plans, marketplace, selectedPlanId);

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
      bottomNavigationBar: requiresAuth
          ? null
          : AarastV3FormActionBar(
              label: 'إرسال الطلب',
              icon: LucideIcons.send,
              loading: marketplace.isSubmitting,
              onPressed: marketplace.isSubmitting ? null : _submit,
            ),
      resizeToAvoidBottomInset: true,
      child: requiresAuth
          ? _QuoteAuthRequired(onLogin: () => context.go(AppRouter.login))
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  AarastV3FocusPrompt(
                    eyebrow: 'طلب واضح',
                    question: 'ما الذي تحتاجه من هذا المزوّد؟',
                    supportingText: provider == null
                        ? 'اختر الخدمة واكتب احتياجك، ثم حسّن التفاصيل إن كانت متاحة.'
                        : 'اكتب احتياجك إلى ${provider.businessName} بوضوح؛ التفاصيل الإضافية تساعد على تسعير أدق.',
                    icon: LucideIcons.fileQuestion,
                  ),
                  const SizedBox(height: 10),
                  AarastV3FormSurface(
                    children: [
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'خطة الزفاف',
                          prefixIcon: Icon(LucideIcons.calendarDays),
                        ),
                        child: Text(
                          selectedContext?.displayName ??
                              'لم يتم اختيار مسار خطة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                        onChanged: (value) {
                          setState(() => _serviceId = value);
                          _scheduleDraft();
                        },
                      ),
                      const SizedBox(height: 10),
                      _DateField(value: _eventDate, onTap: _pickDate),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _messageController,
                        minLines: 2,
                        maxLines: 3,
                        maxLength: 250,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'رسالة للمورد',
                          hintText: 'اكتب تفاصيل التاريخ، الموقع، والاحتياج...',
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
                  const SizedBox(height: 10),
                  AarastV3Disclosure(
                    title: 'حسّن دقة العرض',
                    subtitle: 'المدينة والضيوف ونطاق الميزانية',
                    icon: LucideIcons.slidersHorizontal,
                    child: Column(
                      children: [
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
                          onChanged: (value) {
                            setState(() => _cityId = value);
                            _scheduleDraft();
                          },
                        ),
                        const SizedBox(height: 10),
                        _QuoteLocationContext(location: _eventLocation),
                        const SizedBox(height: 10),
                        _QuoteContactContext(phone: auth.user?.phone),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _guestCountController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'عدد الضيوف المتوقع',
                            prefixIcon: Icon(LucideIcons.users),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final count = int.tryParse(text);
                            if (count == null || count < 1) {
                              return 'أدخل عددًا صحيحًا أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMinController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'من',
                                  suffixText: currencyLabel,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMaxController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'إلى',
                                  suffixText: currencyLabel,
                                ),
                                validator: (value) {
                                  final maxText = value?.trim() ?? '';
                                  final minText = _budgetMinController.text
                                      .trim();
                                  if (maxText.isEmpty || minText.isEmpty) {
                                    return null;
                                  }
                                  final min = num.tryParse(minText);
                                  final max = num.tryParse(maxText);
                                  if (min == null || max == null || max < min) {
                                    return 'أكبر من «من»';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AarastV3LiveSummary(
                    items: [
                      AarastV3SummaryItem(
                        label: 'الخدمة',
                        value: selectedServiceLabel,
                      ),
                      AarastV3SummaryItem(
                        label: 'المناسبة',
                        value: _eventDate == null
                            ? 'دون تاريخ'
                            : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                      ),
                      AarastV3SummaryItem(
                        label: 'النطاق',
                        value: _quoteBudgetSummary(currencyLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (submitError != null) ...[
                    Text(
                      submitError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (marketplace.existingActiveQuote case final quote?)
                      Center(
                        child: TextButton.icon(
                          key: const Key('continue-active-quote'),
                          onPressed: () =>
                              _pushOnce(AppRouter.quoteConversation(quote.id)),
                          icon: const Icon(LucideIcons.messageCircle),
                          label: const Text('متابعة الطلب الحالي'),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (_draft case final draft?) ...[
                    AarastV3DraftStatusLine(status: draft.status),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _handleTextChanged() {
    _scheduleDraft();
    if (mounted) setState(() {});
  }

  String _quoteServiceLabel(List<MarketplaceService> services) {
    final selectedId = _serviceId;
    if (selectedId == null) return 'اقتراح المزوّد';
    for (final service in services) {
      if (service.id == selectedId) return service.title;
    }
    return 'خدمة محددة';
  }

  String _quoteBudgetSummary(String currencyLabel) {
    final min = _budgetMinController.text.trim();
    final max = _budgetMaxController.text.trim();
    if (min.isEmpty && max.isEmpty) return 'غير محدد';
    if (min.isNotEmpty && max.isNotEmpty) {
      return '$min–$max $currencyLabel';
    }
    return '${min.isNotEmpty ? 'من $min' : 'حتى $max'} $currencyLabel';
  }

  Future<void> _restoreDraft() async {
    final draft = await _draft?.restore();
    if (!mounted || draft == null) return;
    _restoringDraft = true;
    try {
      setState(() {
        _serviceId ??= draft['serviceId'] as String?;
        _cityId ??= draft['cityId'] as String?;
        final rawDate = draft['eventDate'] as String?;
        _eventDate ??= rawDate == null ? null : DateTime.tryParse(rawDate);
        if (_guestCountController.text.isEmpty) {
          _guestCountController.text = draft['guestCount'] as String? ?? '';
        }
        if (_budgetMinController.text.isEmpty) {
          _budgetMinController.text = draft['budgetMin'] as String? ?? '';
        }
        if (_budgetMaxController.text.isEmpty) {
          _budgetMaxController.text = draft['budgetMax'] as String? ?? '';
        }
        if (_messageController.text.isEmpty) {
          _messageController.text = draft['message'] as String? ?? '';
        }
      });
    } finally {
      _restoringDraft = false;
    }
  }

  void _scheduleDraft() {
    if (_restoringDraft) return;
    _draft?.schedule({
      'serviceId': _serviceId,
      'cityId': _cityId,
      'eventDate': _eventDate?.toIso8601String(),
      'guestCount': _guestCountController.text,
      'budgetMin': _budgetMinController.text,
      'budgetMax': _budgetMaxController.text,
      'message': _messageController.text,
    });
  }

  String? _safeSelectedService(List<MarketplaceService> services) {
    if (_serviceId == null) return null;
    return services.any((service) => service.id == _serviceId)
        ? _serviceId
        : null;
  }

  String _selectedCurrencyLabel(
    WeddingPlansProvider plans,
    String? selectedPlanId,
  ) {
    final selectedPlan = plans.selectedPlan;
    final currency = selectedPlan?.id == selectedPlanId
        ? selectedPlan?.currency
        : null;
    return currencyLabelAr(currency);
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
    String? selectedPlanId,
  ) {
    if (_didApplyInitialPlanContext || selectedPlanId == null) return;
    final selectedPlan = plans.selectedPlan;
    if (selectedPlan == null || selectedPlan.id != selectedPlanId) return;
    _didApplyInitialPlanContext = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = selectedPlan.weddingLocation;
      final matchingCityId = _matchingCityId(marketplace, location);
      setState(() {
        _eventDate ??= selectedPlan.weddingDate;
        if (location.hasAnyLocation) {
          _eventLocation ??= location;
        }
        _cityId ??= matchingCityId;
      });
      _prefillLocationMessage(location);
    });
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
    releaseFieldFocus();
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
      _scheduleDraft();
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

    final selectedContext = context
        .read<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = selectedContext?.isPlan == true
        ? selectedContext?.weddingPlanId
        : null;
    if (selectedPlanId == null) {
      AarastToast.showError(
        context,
        'اختر مسار خطة الزفاف قبل إرسال طلب عرض السعر.',
      );
      return;
    }

    final guestCount = int.tryParse(_guestCountController.text.trim());
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final success = await marketplace.createQuoteRequest(
      providerId: widget.providerId,
      weddingPlanId: selectedPlanId,
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
      await _draft?.clear();
      if (!mounted) return;
      final createdQuote = marketplace.lastCreatedQuote;
      final responsePlanId = createdQuote?.weddingPlanId?.trim();
      AarastFormSuccess.show(context, message: 'تم إرسال طلب عرض السعر بنجاح.');
      if (responsePlanId != null &&
          responsePlanId.isNotEmpty &&
          responsePlanId != selectedPlanId) {
        AarastToast.showError(
          context,
          'تعذر تأكيد ارتباط الطلب بمسار الخطة المحدد.',
        );
        return;
      }
      context.go(
        AppRouter.planProviders(selectedPlanId, quoteId: createdQuote?.id),
      );
    }
  }

  Future<T?> _pushOnce<T>(String location, {Object? extra}) async {
    if (!mounted || !_routeLaunchesInFlight.add(location)) return null;
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      _routeLaunchesInFlight.remove(location);
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
            color: hasLocation ? AppTheme.success : AppTheme.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
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
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
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
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.phoneCall, color: AppTheme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رقم التواصل',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                if (displayPhone != null)
                  AarastPhoneText(
                    phone: displayPhone,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  )
                else
                  const Text(
                    'سيُستخدم رقم الحساب عند إرسال الطلب بعد تسجيل الدخول.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
            color: value == null
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
