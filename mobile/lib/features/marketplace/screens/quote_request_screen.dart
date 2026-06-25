import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../wedding_plans/models/wedding_plan.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({
    required this.providerId,
    this.initialServiceId,
    super.key,
  });

  final String providerId;
  final String? initialServiceId;

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
  bool _sent = false;
  bool _didApplyInitialPlanContext = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initialServiceId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final marketplace = context.read<ProviderMarketplaceProvider>();
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
          !AppFeatureFlags.devBypassLoginGatesForUxExploration ||
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
    final auth = context.watch<AuthController>();
    final provider = marketplace.providerDetails(widget.providerId);
    final services = marketplace.servicesFor(widget.providerId);
    _scheduleInitialPlanContext(plans, marketplace);

    return AarastPageScaffold(
      title: 'طلب عرض سعر',
      subtitle: provider == null
          ? 'حددي احتياجك للمورد'
          : 'إلى ${provider.businessName}',
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      resizeToAvoidBottomInset: true,
      child: _sent
          ? _QuoteSentState(
              onMarketplace: () => context.go(AppRouter.providerMarketplace),
            )
          : auth.status == AuthStatus.unauthenticated &&
                !AppFeatureFlags.devBypassLoginGatesForUxExploration
          ? _QuoteAuthRequired(onLogin: () => context.go(AppRouter.login))
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  _QuoteIntro(provider: provider),
                  const SizedBox(height: 18),
                  AarastCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _weddingPlanId,
                          decoration: const InputDecoration(
                            labelText: 'خطة الزفاف',
                            prefixIcon: Icon(Icons.event_note_outlined),
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
                            prefixIcon: Icon(Icons.design_services_outlined),
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
                            prefixIcon: Icon(Icons.place_outlined),
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
                            prefixIcon: Icon(Icons.people_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMinController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'أقل ميزانية',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMaxController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'أعلى ميزانية',
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
                                'اكتبي تفاصيل التاريخ، الموقع، والاحتياج...',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 8) {
                              return 'اكتبي تفاصيل قصيرة ليفهم المورد طلبك';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (marketplace.errorMessage != null) ...[
                    Text(
                      marketplace.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: marketplace.isSubmitting ? null : _submit,
                    icon: marketplace.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('إرسال الطلب'),
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
    final success = await context
        .read<ProviderMarketplaceProvider>()
        .createQuoteRequest(
          providerId: widget.providerId,
          weddingPlanId: _weddingPlanId,
          serviceId: _serviceId,
          eventDate: _eventDate,
          location: _eventLocation?.toJson(),
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
      final notice = context.read<ProviderMarketplaceProvider>().noticeMessage;
      if (notice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
      setState(() => _sent = true);
    }
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
        : 'أضيفي موقع الزفاف حتى يفهم المورد مكان المناسبة قبل تسعير الطلب.';
    final label = location?.fullLabel ?? location?.mediumLabel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasLocation ? AppTheme.success.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: hasLocation
              ? AppTheme.success.withValues(alpha: 0.22)
              : AppTheme.dLine,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasLocation ? Icons.location_on_outlined : Icons.add_location_alt,
            color: hasLocation ? AppTheme.success : AppTheme.dMaroon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
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
                      color: AppTheme.dMaroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_in_talk_outlined, color: AppTheme.dMaroon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رقم التواصل',
                  style: TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayPhone ??
                      'سيُستخدم رقم الحساب عند إرسال الطلب بعد تسجيل الدخول.',
                  textDirection: displayPhone == null
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
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

class _QuoteSentState extends StatelessWidget {
  const _QuoteSentState({required this.onMarketplace});

  final VoidCallback onMarketplace;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        AarastEmptyState(
          icon: Icons.mark_email_read_outlined,
          title: 'تم إرسال طلبك للمزود',
          message: 'سيظهر الطلب لدى المزود ضمن طلبات عروض الأسعار.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onMarketplace,
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('العودة للموردين'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRouter.home),
                icon: const Icon(Icons.home_rounded),
                label: const Text('الرئيسية'),
              ),
            ],
          ),
        ),
      ],
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
          icon: Icons.lock_outline_rounded,
          title: 'تسجيل الدخول مطلوب',
          message: 'سجلي الدخول أولاً لإرسال طلب عرض سعر للمزود.',
          action: FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل الدخول'),
          ),
        ),
      ],
    );
  }
}

class _QuoteIntro extends StatelessWidget {
  const _QuoteIntro({required this.provider});

  final MarketplaceProvider? provider;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.dPinkBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.dMaroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider == null
                  ? 'ارسلي طلبًا واضحًا وسيصل للمورد عبر النظام عند توفر البيانات.'
                  : 'اكتبي تفاصيلك وسيتم إرسالها إلى ${provider!.businessName} ضمن طلبات عروض الأسعار.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
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
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null
              ? 'اختاري التاريخ'
              : '${value!.day}/${value!.month}/${value!.year}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: value == null ? AppTheme.dMuted : AppTheme.dInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
