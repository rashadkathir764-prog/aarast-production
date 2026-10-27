import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, WeddingLocationDraft;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, WeddingPlansProvider;
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../providers/marketplace_provider.dart';

/// f07 «اطلب عرض سعر»: what is needed, what the plan already says (the day,
/// the time, the place and, for halls and catering, the guests), an optional
/// word, and whether to share the item's amount. The phone number always
/// reaches the provider (C46), so nothing promises otherwise.
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

/// The times of day a request can name; it reaches the provider in the
/// message, since a request has no time of its own.
const _periods = ['الصبح', 'الظهر', 'الليل · بعد المغرب'];

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final _guestCountController = TextEditingController();
  final _messageController = TextEditingController();

  String? _serviceId;
  String? _cityId;
  String? _period;
  DateTime? _eventDate;
  WeddingLocationDraft? _eventLocation;
  bool _shareBudget = false;

  /// B-08: the phone reaches the provider only when shared.
  bool _shareContact = false;
  String? _guestError;
  bool _didApplyInitialPlanContext = false;
  final Set<String> _routeLaunchesInFlight = <String>{};
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initialServiceId;
    for (final controller in [_guestCountController, _messageController]) {
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

  @override
  void dispose() {
    _draft?.dispose();
    for (final controller in [_guestCountController, _messageController]) {
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
    final auth = context.watch<AuthController>();
    final provider = marketplace.providerDetails(widget.providerId);
    final services = marketplace.servicesFor(widget.providerId);
    final submitError =
        marketplace.quoteSubmitErrorMessage ?? marketplace.errorMessage;
    final requiresAuth =
        auth.status == AuthStatus.unauthenticated &&
        !AppFeatureFlags.devBypassLoginGatesForUxExploration;
    final budget = _budgetIntent(provider, services, selectedPlanId);
    final asksGuests = _asksGuests(provider, services);
    _scheduleInitialPlanContext(plans, marketplace, selectedPlanId);

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: requiresAuth
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: JourneyButton(
                  key: const ValueKey('quote-send'),
                  label: context.say('أرسل الطلب', 'أرسلي الطلب'),
                  icon: LucideIcons.send,
                  background: AarastV3Color.cobalt,
                  large: true,
                  expand: true,
                  loading: marketplace.isSubmitting,
                  onPressed: marketplace.isSubmitting
                      ? null
                      : () => _submit(budget, asksGuests),
                ),
              ),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          JourneySubHeader(
            title: context.say('اطلب عرض سعر', 'اطلبي عرض سعر'),
            subtitle: provider == null ? null : 'إلى ${provider.businessName}',
            onBack: () {
              if (context.canPop()) context.pop();
            },
          ),
          if (requiresAuth)
            JourneyListState(
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyIcon: LucideIcons.logIn,
              emptyTitle: context.say('ادخل حسابك أول', 'ادخلي حسابك أول'),
              emptyMessage: context.say(
                'الطلب يوصل المزود من حسابك، وتتابعه منه.',
                'الطلب يوصل المزود من حسابك، وتتابعينه منه.',
              ),
              emptyAction: context.say('ادخل', 'ادخلي'),
              onEmptyAction: () => context.go(AppRouter.login),
            )
          else ...[
            if (services.isNotEmpty) ...[
              _Label(context.say('ايش تحتاج؟', 'ايش تحتاجين؟')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final service in services)
                    JourneyChip(
                      key: ValueKey('quote-service-${service.id}'),
                      label: service.title,
                      selected: _serviceId == service.id,
                      selectedColor: AarastV3Color.cobalt,
                      onTap: () {
                        setState(
                          () => _serviceId = _serviceId == service.id
                              ? null
                              : service.id,
                        );
                        _scheduleDraft();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            _Label('من خطتك'),
            JourneyBox(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _PlanRow(
                    key: const Key('quote-day'),
                    icon: LucideIcons.calendarDays,
                    label: 'اليوم',
                    value: _eventDate == null
                        ? null
                        : formatArabicWeekdayDayMonth(_eventDate!),
                    onEdit: _pickDate,
                  ),
                  _PlanRow(
                    key: const Key('quote-period'),
                    icon: LucideIcons.clock,
                    label: 'الفترة',
                    value: _period,
                    onEdit: _pickPeriod,
                  ),
                  _PlanRow(
                    key: const Key('quote-place'),
                    icon: LucideIcons.mapPin,
                    label: 'المكان',
                    value: _placeLabel(marketplace),
                    onEdit: () => _pickCity(marketplace),
                  ),
                  if (asksGuests)
                    _PlanRow(
                      key: const Key('quote-guests'),
                      icon: LucideIcons.users,
                      label: context.say('الضيوف', 'الضيفات'),
                      value: _guestCountController.text.trim().isEmpty
                          ? null
                          : '${_guestCountController.text.trim()} تقريبًا',
                      onEdit: _pickGuests,
                    ),
                ],
              ),
            ),
            if (_guestError != null) ...[
              const SizedBox(height: 6),
              Text(
                _guestError!,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.danger,
                ),
              ),
            ],
            const SizedBox(height: 12),
            JourneyTextField(
              key: const Key('quote-message'),
              label: 'كلمة لهم (اختياري)',
              controller: _messageController,
              hint: 'أي تفصيل يهمّك يعرفوه',
              maxLength: 250,
              minLines: 1,
              maxLines: 3,
            ),
            // B-08: the budget and the phone reach the provider only when
            // shared; B-04: the request ends after seven days unanswered.
            const SizedBox(height: 12),
            JourneyBox(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                children: [
                  if (budget != null)
                    _ShareRow(
                      toggleKey: const Key('quote-share-budget'),
                      title:
                          '${context.say('شاركهم', 'شاركيهم')} بندك: '
                          '${_amountLabel(budget.allocatedValue, plans, selectedPlanId)}',
                      subtitle: 'يساعدهم يعطونك عرض على قدّك',
                      value: _shareBudget,
                      onChanged: (value) {
                        setState(() => _shareBudget = value);
                        _scheduleDraft();
                      },
                    ),
                  _ShareRow(
                    toggleKey: const Key('quote-share-contact'),
                    title: '${context.say('شاركهم', 'شاركيهم')} رقمك',
                    subtitle: 'غير كذا يكلمونك من الرسائل بس',
                    value: _shareContact,
                    onChanged: (value) {
                      setState(() => _shareContact = value);
                      _scheduleDraft();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            JourneyNote(
              text: budget != null
                  ? context.say(
                      'بندك ورقمك ما يوصلونهم إلا إذا فعّلتهم. والطلب ينتهي لو ما ردوا خلال 7 أيام.',
                      'بندك ورقمك ما يوصلونهم إلا إذا فعّلتيهم. والطلب ينتهي لو ما ردوا خلال 7 أيام.',
                    )
                  : context.say(
                      'رقمك ما يوصلهم إلا إذا فعّلته. والطلب ينتهي لو ما ردوا خلال 7 أيام.',
                      'رقمك ما يوصلهم إلا إذا فعّلتيه. والطلب ينتهي لو ما ردوا خلال 7 أيام.',
                    ),
              icon: LucideIcons.lock,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
            ),
            if (submitError != null) ...[
              const SizedBox(height: 12),
              Text(
                submitError,
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: AarastV3Color.danger,
                ),
              ),
              if (marketplace.existingActiveQuote case final quote?)
                Center(
                  child: JourneyTextAction(
                    key: const Key('continue-active-quote'),
                    label: context.say('كمّل طلبك الحالي', 'كمّلي طلبك الحالي'),
                    icon: LucideIcons.messageCircle,
                    color: AarastV3Color.cobalt,
                    onPressed: () =>
                        _pushOnce(AppRouter.quoteConversation(quote.id)),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  void _handleTextChanged() {
    _scheduleDraft();
    if (mounted) setState(() {});
  }

  /// «1.5 مليون ر.ي» in the open plan's currency.
  String _amountLabel(
    num value,
    WeddingPlansProvider plans,
    String? selectedPlanId,
  ) {
    final plan = plans.selectedPlan;
    final currency = plan?.id == selectedPlanId ? plan?.currency : null;
    final parts = compactMoneyParts(
      value,
      currencyCode: currencyCodeFromDisplayInput(currency),
    );
    return [
      parts.number,
      ?parts.millionUnit,
      currencyLabelAr(currency),
    ].join(' ');
  }

  /// The amount the request may share: the item it came from, or the plan's
  /// item for this kind of service; null when there is none to share.
  ProviderBudgetMatchIntent? _budgetIntent(
    MarketplaceProvider? provider,
    List<MarketplaceService> services,
    String? planId,
  ) {
    final given = widget.initialBudgetIntent;
    if (given != null && given.hasBudget) return given;
    final finance = context.read<FinanceProvider?>();
    if (planId == null || finance?.loadedPlanId != planId) return null;
    // G40: the item this request's offer would land in, as the server
    // lists each item's categories.
    final kind = _kind(provider, services);
    final item = budgetItemForCategories(
      finance!.categories,
      (item) => finance.providerCategoryIdsFor(item.id),
      [kind?.id ?? provider?.primaryCategoryId],
    );
    if (item == null) return null;
    final intent = ProviderBudgetMatchIntent(
      budgetCategoryName: item.name,
      allocatedAmount: item.allocatedAmount,
      providerCategoryIds: finance.providerCategoryIdsFor(item.id),
    );
    return intent.hasBudget ? intent : null;
  }

  /// C45: only halls and catering are told how many guests come; the
  /// catalog's own slugs say which those are.
  bool _asksGuests(
    MarketplaceProvider? provider,
    List<MarketplaceService> services,
  ) {
    final slug = _kind(provider, services)?.slug;
    return slug == venueCategorySlug || slug == cateringCategorySlug;
  }

  /// The kind of the chosen service, else the provider's own kind (the
  /// category acceptance files the offer by).
  ProviderCategory? _kind(
    MarketplaceProvider? provider,
    List<MarketplaceService> services,
  ) {
    for (final service in services) {
      if (service.id == _serviceId) return service.category;
    }
    return provider?.primaryCategory ?? services.firstOrNull?.category;
  }

  String? _placeLabel(ProviderMarketplaceProvider marketplace) {
    final location = _eventLocation;
    final label = location?.mediumLabel ?? location?.shortLabel;
    return label ?? _selectedCityName(marketplace);
  }

  Future<void> _restoreDraft() async {
    final draft = await _draft?.restore();
    if (!mounted || draft == null) return;
    _restoringDraft = true;
    try {
      setState(() {
        _serviceId ??= draft['serviceId'] as String?;
        _cityId ??= draft['cityId'] as String?;
        _period ??= draft['period'] as String?;
        _shareBudget = draft['shareBudget'] == true;
        _shareContact = draft['shareContact'] == true;
        final rawDate = draft['eventDate'] as String?;
        _eventDate ??= rawDate == null ? null : DateTime.tryParse(rawDate);
        if (_guestCountController.text.isEmpty) {
          _guestCountController.text = draft['guestCount'] as String? ?? '';
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
      'period': _period,
      'shareBudget': _shareBudget,
      'shareContact': _shareContact,
      'eventDate': _eventDate?.toIso8601String(),
      'guestCount': _guestCountController.text,
      'message': _messageController.text,
    });
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
      if (location.hasAnyLocation) _eventLocation = location;
      _eventDate ??= guestPlan.weddingDate;
    });
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
      final summary = context.read<DashboardSummaryProvider?>()?.summary;
      final guests = summary?.planId == selectedPlanId
          ? summary!.guestCount
          : 0;
      setState(() {
        _eventDate ??= selectedPlan.weddingDate;
        if (location.hasAnyLocation) _eventLocation ??= location;
        _cityId ??= matchingCityId;
        if (_guestCountController.text.isEmpty && guests > 0) {
          _guestCountController.text = '$guests';
        }
      });
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

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _eventDate = picked);
    _scheduleDraft();
  }

  Future<void> _pickPeriod() async {
    releaseFieldFocus();
    final picked = await _choose<String>(
      title: 'الفترة',
      options: [for (final period in _periods) (period, period)],
      selected: _period,
    );
    if (picked == null || !mounted) return;
    setState(() => _period = picked);
    _scheduleDraft();
  }

  Future<void> _pickCity(ProviderMarketplaceProvider marketplace) async {
    releaseFieldFocus();
    final picked = await _choose<String>(
      title: 'المكان',
      options: [for (final city in marketplace.cities) (city.id, city.nameAr)],
      selected: _cityId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // Another city drops the plan's venue, which belongs to the old one.
      if (picked != _cityId) _eventLocation = null;
      _cityId = picked;
    });
    _scheduleDraft();
  }

  Future<void> _pickGuests() async {
    releaseFieldFocus();
    final value = await showJourneySheet<String>(
      context: context,
      builder: (_) => _GuestsSheet(initial: _guestCountController.text),
    );
    if (value == null || !mounted) return;
    setState(() {
      _guestCountController.text = value.trim();
      _guestError = null;
    });
  }

  /// A short list to pick one from, with the current one marked.
  Future<T?> _choose<T>({
    required String title,
    required List<(T, String)> options,
    required T? selected,
  }) {
    return showJourneySheet<T>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: title,
        children: [
          for (final (value, label) in options) ...[
            JourneyChoiceCard(
              title: label,
              subtitle: '',
              leading: const SizedBox.shrink(),
              selected: value == selected,
              onTap: () => Navigator.of(sheetContext).pop(value),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(
    ProviderBudgetMatchIntent? budget,
    bool asksGuests,
  ) async {
    final guestText = _guestCountController.text.trim();
    final guestCount = asksGuests && guestText.isNotEmpty
        ? int.tryParse(guestText)
        : null;
    if (asksGuests && guestText.isNotEmpty && (guestCount ?? 0) < 1) {
      setState(
        () => _guestError = context.say(
          'اكتب عدد الضيوف بالأرقام',
          'اكتبي عدد الضيفات بالأرقام',
        ),
      );
      return;
    }
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
        context.say(
          'افتح خطتك أول، وبعدين اطلب العرض.',
          'افتحي خطتك أول، وبعدين اطلبي العرض.',
        ),
      );
      return;
    }

    final marketplace = context.read<ProviderMarketplaceProvider>();
    final shared = _shareBudget ? budget : null;
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
      // B-08: the amount and the phone reach the provider only when shared.
      budgetMin: shared?.requestMin?.round().toString() ?? '',
      budgetMax: shared?.requestMax?.round().toString() ?? '',
      shareBudget: shared != null,
      shareContact: _shareContact,
      message: [
        if (_period != null) 'الفترة: $_period',
        if (_messageController.text.trim().isNotEmpty)
          _messageController.text.trim(),
      ].join('\n'),
    );

    if (!mounted) return;
    if (success) {
      await _draft?.clear();
      if (!mounted) return;
      final createdQuote = marketplace.lastCreatedQuote;
      final responsePlanId = createdQuote?.weddingPlanId?.trim();
      AarastFormSuccess.show(context, message: 'وصل طلبك للمزود.');
      if (responsePlanId != null &&
          responsePlanId.isNotEmpty &&
          responsePlanId != selectedPlanId) {
        AarastToast.showError(
          context,
          'ما قدرنا نتأكد إن الطلب في خطتك المفتوحة.',
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
    if (location.hasRequiredLocation) return location.toJson();

    final city = _cleanText(location.cityOrDistrict) ?? selectedCityName;
    if (city != null) return {'city': city};

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

/// «كم ضيف تقريبًا؟», owning its field for as long as the sheet lives.
class _GuestsSheet extends StatefulWidget {
  const _GuestsSheet({required this.initial});

  final String initial;

  @override
  State<_GuestsSheet> createState() => _GuestsSheetState();
}

class _GuestsSheetState extends State<_GuestsSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: null,
      children: [
        JourneyTextField(
          label: context.say('كم ضيف تقريبًا؟', 'كم ضيفة تقريبًا؟'),
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
        ),
        const SizedBox(height: 12),
        JourneyButton(
          label: 'تمام',
          background: AarastV3Color.cobalt,
          large: true,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

/// One f07 sharing switch: what is shared, why, and its toggle (B-08).
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.toggleKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key toggleKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          JourneyToggle(
            key: toggleKey,
            value: value,
            color: AarastV3Color.cobalt,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        text,
        style: JourneyType.of(
          JourneyType.body,
          weight: JourneyType.bold,
          color: AarastV3Color.textMuted,
        ),
      ),
    );
  }
}

/// One fact from the plan, with the pencil that changes it.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Null when the plan does not say yet.
  final String? value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onEdit,
      semanticLabel:
          '$label، ${value ?? context.say('ما حددت', 'ما حددتِ')}، ${context.say('غيّر', 'غيّري')}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AarastV3Color.cobalt),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value ?? context.say('ما حددت', 'ما حددتِ'),
                style: JourneyType.of(
                  JourneyType.body,
                  weight: value == null ? FontWeight.w400 : JourneyType.bold,
                  color: value == null
                      ? AarastV3Color.textMuted
                      : AarastV3Color.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.pencil,
              size: 18,
              color: AarastV3Color.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
