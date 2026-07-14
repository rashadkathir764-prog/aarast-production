import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../marketplace/models/accepted_quote_cost_draft.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../../marketplace/widgets/plan_quote_requests_section.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../sharing/models/shared_member.dart';
import '../models/dashboard_summary.dart';
import '../models/wedding_plan.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/plan_management_view.dart';
import '../widgets/royal_home_chrome.dart';

class PlanCenterScreen extends StatefulWidget {
  const PlanCenterScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.initialSummary,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final DashboardSummary? initialSummary;

  @override
  State<PlanCenterScreen> createState() => _PlanCenterScreenState();
}

class _PlanCenterScreenState extends State<PlanCenterScreen> {
  WeddingPlan? _localPlan;
  bool _localLoading = false;
  String? _localError;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant PlanCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.sharedMember != widget.sharedMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_isLocalPlan) {
      await _loadLocalPlan();
      return;
    }
    await Future.wait([
      context.read<WeddingPlansProvider>().loadWeddingPlan(
        widget.weddingPlanId,
      ),
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      ),
      context.read<ProviderMarketplaceProvider>().loadMyQuoteRequests(),
    ]);
  }

  Future<void> _loadLocalPlan() async {
    setState(() {
      _localLoading = true;
      _localError = null;
    });
    try {
      final draft = await context
          .read<GuestOnboardingStorage>()
          .loadGuestPlan();
      if (!mounted) return;
      if (draft == null) {
        setState(() => _localError = 'لم يتم العثور على بيانات الخطة المحلية.');
        return;
      }
      setState(() => _localPlan = _weddingPlanFromDraft(draft));
    } on Object {
      if (mounted) {
        setState(() => _localError = 'تعذر تحميل بيانات الخطة المحلية.');
      }
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingPlans = context.watch<WeddingPlansProvider>();
    final dashboard = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();
    final marketplace = _isLocalPlan
        ? null
        : context.watch<ProviderMarketplaceProvider>();
    final serverPlan = weddingPlans.selectedPlan?.id == widget.weddingPlanId
        ? weddingPlans.selectedPlan
        : null;
    final plan = _isLocalPlan ? _localPlan : serverPlan;
    final isLoading = _isLocalPlan
        ? _localLoading
        : (weddingPlans.isLoading || dashboard.isLoading) && plan == null;
    final error = _isLocalPlan
        ? _localError
        : weddingPlans.errorMessage ?? dashboard.errorMessage;
    final quotes = marketplace?.quotesForPlan(widget.weddingPlanId) ?? const [];
    final canManageProviders = plan == null
        ? false
        : _canManageProviders(auth, dashboard, plan);
    final canManageMoney = plan == null
        ? false
        : _canManageMoney(auth, dashboard, plan);

    return AarastScreenFrame(
      maxWidth: 560,
      safeAreaBottom: false,
      bottomNavigationBar: _buildBottomNav(widget.weddingPlanId),
      child: isLoading
          ? const AarastScreenLoading(label: 'جارٍ تحميل بيانات الخطة...')
          : plan == null
          ? _ManagementLoadError(message: error, onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.burgundy,
              onRefresh: _load,
              child: PlanManagementView(
                plan: plan,
                ownerName: _ownerName(auth, plan),
                participantCount: _isLocalPlan
                    ? 1
                    : dashboard.summary?.participantCount,
                pendingInvites: _isLocalPlan
                    ? 0
                    : dashboard.summary?.pendingInvites ?? 0,
                canManagePlan: _canManagePlan(auth, dashboard, plan),
                canManageSharing:
                    !_isLocalPlan &&
                    widget.sharedMember == null &&
                    auth.user?.id == plan.ownerUserId,
                isLocalPlan: _isLocalPlan,
                onBack: _goBack,
                onEditBasics: () => _showEditPlan(plan),
                onEditLocation: () =>
                    _showEditPlan(plan, requireCompleteLocation: true),
                onManageSharing: () => context.push(AppRouter.sharing(plan.id)),
                onArchive: _isLocalPlan ? null : () => _confirmArchive(plan),
                quoteSection: quotes.isEmpty
                    ? null
                    : PlanQuoteRequestsSection(
                        quotes: quotes,
                        canManageProviders: canManageProviders,
                        canManageMoney: canManageMoney,
                        isSubmitting: marketplace?.isSubmitting ?? false,
                        onOpenConversation: (quote) =>
                            context.push(AppRouter.quoteConversation(quote.id)),
                        onAccept: _acceptQuote,
                        onReject: _rejectQuote,
                        onCreateCost: (quote) =>
                            _openCostFromAcceptedQuote(plan, quote),
                      ),
              ),
            ),
    );
  }

  bool _canManagePlan(
    AuthController auth,
    DashboardSummaryProvider dashboard,
    WeddingPlan plan,
  ) {
    if (_isLocalPlan) return true;
    return dashboard.summary?.permissions.canManagePlan == true ||
        auth.user?.id == plan.ownerUserId ||
        widget.sharedMember?.role == 'MANAGER';
  }

  bool _canManageProviders(
    AuthController auth,
    DashboardSummaryProvider dashboard,
    WeddingPlan plan,
  ) {
    if (_isLocalPlan) return false;
    final permissions =
        dashboard.summary?.permissions ?? widget.initialSummary?.permissions;
    return auth.user?.id == plan.ownerUserId ||
        permissions?.canManageProviders == true ||
        widget.sharedMember?.canManageProviders == true;
  }

  bool _canManageMoney(
    AuthController auth,
    DashboardSummaryProvider dashboard,
    WeddingPlan plan,
  ) {
    if (_isLocalPlan) return true;
    final permissions =
        dashboard.summary?.permissions ?? widget.initialSummary?.permissions;
    return auth.user?.id == plan.ownerUserId ||
        permissions?.canManageMoney == true ||
        widget.sharedMember?.canManageMoney == true;
  }

  Future<void> _acceptQuote(QuoteRequest quote) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final accepted = await marketplace.acceptQuote(quote);
    if (!mounted) return;
    if (!accepted) {
      _showError(marketplace.errorMessage ?? 'تعذر قبول عرض السعر.');
      return;
    }
    _showSuccess(
      'تم قبول العرض وربط المورد بالخطة. لم تُنشأ تكلفة أو دفعة تلقائيًا.',
    );
  }

  Future<void> _rejectQuote(QuoteRequest quote) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final rejected = await marketplace.rejectQuote(quote);
    if (!mounted) return;
    if (!rejected) {
      _showError(marketplace.errorMessage ?? 'تعذر رفض عرض السعر.');
      return;
    }
    _showSuccess('تم رفض العرض.');
  }

  Future<void> _openCostFromAcceptedQuote(
    WeddingPlan plan,
    QuoteRequest quote,
  ) async {
    final intent = costDraftIntentFromAcceptedQuote(
      quote,
      fallbackCurrency: plan.currency,
    );
    if (intent == null) {
      _showError('لا يمكن إنشاء تكلفة من هذا العرض الآن.');
      return;
    }
    final result = await context.push<bool>(
      AppRouter.moneyCostCreate(plan.id),
      extra: intent,
    );
    if (result != true || !mounted) return;

    await context.read<ProviderMarketplaceProvider>().loadMyQuoteRequests();
    if (mounted) _showSuccess('تمت إضافة التكلفة إلى تبويب المال.');
  }

  String _ownerName(AuthController auth, WeddingPlan plan) {
    if (_isLocalPlan || auth.user?.id == plan.ownerUserId) {
      final name = auth.user?.name.trim() ?? '';
      return name.isNotEmpty ? name : 'أنت';
    }
    return 'صاحب الخطة';
  }

  Future<void> _showEditPlan(
    WeddingPlan plan, {
    bool requireCompleteLocation = false,
  }) async {
    final result = await showAarastBottomSheet<_PlanEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.ivory,
      builder: (_) => _PlanEditSheet(
        plan: plan,
        requireCompleteLocation: requireCompleteLocation,
      ),
    );
    if (result == null || !mounted) return;

    if (_isLocalPlan) {
      await _saveLocalEdit(result);
      return;
    }

    final provider = context.read<WeddingPlansProvider>();
    final updated = await provider.updateWeddingPlan(
      plan.id,
      result.toUpdateJson(),
    );
    if (!mounted) return;
    if (updated == null) {
      _showError(provider.errorMessage ?? 'تعذر تحديث الخطة.');
      return;
    }
    await context.read<DashboardSummaryProvider>().loadDashboard(
      plan.id,
      sharedMember: widget.sharedMember,
    );
    if (mounted) _showSuccess('تم تحديث بيانات الخطة.');
  }

  Future<void> _saveLocalEdit(_PlanEditResult result) async {
    final storage = context.read<GuestOnboardingStorage>();
    final draft = await storage.loadGuestPlan();
    if (draft == null) {
      if (mounted) _showError('تعذر العثور على الخطة المحلية.');
      return;
    }
    final location = result.location;
    final updated = draft.copyWith(
      planName: result.title,
      weddingDate: result.weddingDate,
      weddingDateUnknown: false,
      currency: result.currency,
      priorities: result.priorities,
      governorate: location?.governorate,
      city: location?.cityOrDistrict,
      district: location?.areaOrNeighborhood,
      street: location?.street,
      addressNote: location?.detailedAddress,
    );
    await storage.saveDraft(updated);
    await _loadLocalPlan();
    if (mounted) _showSuccess('تم تحديث الخطة على هذا الجهاز.');
  }

  Future<void> _confirmArchive(WeddingPlan plan) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.ivory,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  LucideIcons.archive,
                  color: AppTheme.danger,
                  size: 34,
                ),
                const SizedBox(height: 12),
                const Text(
                  'أرشفة الخطة؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم نقل "${plan.title}" إلى الأرشيف دون حذف بياناتها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(LucideIcons.archive),
                        label: const Text('أرشفة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WeddingPlansProvider>();
    final archived = await provider.archiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (archived == null) {
      _showError(provider.errorMessage ?? 'تعذر أرشفة الخطة.');
      return;
    }
    context.go(AppRouter.weddingPlans);
  }

  WeddingPlan _weddingPlanFromDraft(GuestOnboardingDraft draft) {
    return WeddingPlan(
      id: draft.guestPlanId ?? widget.weddingPlanId,
      ownerUserId: 'local-user',
      title: draft.planName?.trim().isNotEmpty == true
          ? draft.planName!.trim()
          : 'خطة الزفاف',
      city: draft.city,
      location: draft.weddingLocation.toJson(),
      weddingDate: draft.weddingDate,
      priorities: draft.priorities,
      onboardingPath: draft.selectedPath?.name.toUpperCase(),
      persona: draft.persona?.name.toUpperCase(),
      estimatedBudget: draft.estimatedBudget,
      currency: draft.currency ?? 'YER',
      status: 'PLANNING',
      createdAt: draft.createdAt ?? DateTime.now(),
      updatedAt: draft.createdAt ?? DateTime.now(),
    );
  }

  void _showError(String message) => AarastToast.showError(context, message);

  void _showSuccess(String message) =>
      AarastToast.showSuccess(context, message);

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.home);
    }
  }

  Widget _buildBottomNav(String planId) {
    return RoyalDashboardBottomNav(
      activeIndex: 0,
      onHome: () => context.go(AppRouter.weddingPlanDashboard(planId)),
      onMoney: () =>
          context.go(AppRouter.money(planId), extra: widget.sharedMember),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onGuests: () => context.go(AppRouter.guestList(planId)),
      onProviders: () => context.go(AppRouter.planProviders(planId)),
    );
  }
}

class _PlanEditSheet extends StatefulWidget {
  const _PlanEditSheet({
    required this.plan,
    required this.requireCompleteLocation,
  });

  final WeddingPlan plan;
  final bool requireCompleteLocation;

  @override
  State<_PlanEditSheet> createState() => _PlanEditSheetState();
}

class _PlanEditSheetState extends State<_PlanEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _governorate;
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _street;
  late final TextEditingController _details;
  late DateTime? _weddingDate;
  late String _currency;
  late Set<String> _priorities;
  String? _error;

  static const _priorityOptions = {
    'budget': 'الميزانية',
    'tasks': 'المهام',
    'guests': 'الضيوف',
    'providers': 'الموردون',
  };

  @override
  void initState() {
    super.initState();
    final location = widget.plan.weddingLocation;
    _title = TextEditingController(text: widget.plan.title);
    _governorate = TextEditingController(text: location.governorate ?? '');
    _city = TextEditingController(
      text: location.cityOrDistrict ?? widget.plan.city ?? '',
    );
    _area = TextEditingController(text: location.areaOrNeighborhood ?? '');
    _street = TextEditingController(text: location.street ?? '');
    _details = TextEditingController(text: location.detailedAddress ?? '');
    _weddingDate = widget.plan.weddingDate;
    _currency = _supportedCurrency(widget.plan.currency);
    _priorities = widget.plan.priorities.toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _governorate.dispose();
    _city.dispose();
    _area.dispose();
    _street.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _weddingDate = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final location = WeddingLocationDraft(
      governorate: _clean(_governorate.text),
      cityOrDistrict: _clean(_city.text),
      areaOrNeighborhood: _clean(_area.text),
      street: _clean(_street.text),
      detailedAddress: _clean(_details.text),
    );
    if (title.isEmpty) {
      setState(() => _error = 'اسم الخطة مطلوب.');
      return;
    }
    if (widget.requireCompleteLocation && !location.hasRequiredLocation) {
      setState(() => _error = 'المحافظة والمدينة مطلوبتان لتحديث الموقع.');
      return;
    }

    Navigator.pop(
      context,
      _PlanEditResult(
        title: title,
        weddingDate: _weddingDate,
        currency: _currency,
        priorities: _priorities.toList(growable: false),
        location: location.hasRequiredLocation ? location : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPriorities = {..._priorityOptions.keys, ...widget.plan.priorities};
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تعديل بيانات الخطة',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'اسم الخطة'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(LucideIcons.calendar),
                  label: Text(
                    _weddingDate == null
                        ? 'اختيار تاريخ الزواج'
                        : '${_weddingDate!.day}/${_weddingDate!.month}/${_weddingDate!.year}',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  items: const [
                    DropdownMenuItem(value: 'YER', child: Text('ريال يمني')),
                    DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي')),
                    DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _currency = value);
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'موقع الزفاف',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _governorate,
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / المديرية',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _area,
                  decoration: const InputDecoration(
                    labelText: 'الحي / المنطقة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _street,
                  decoration: const InputDecoration(labelText: 'الشارع'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'العنوان التفصيلي',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الأولويات',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final priority in allPriorities)
                      FilterChip(
                        label: Text(_priorityOptions[priority] ?? priority),
                        selected: _priorities.contains(priority),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _priorities.add(priority);
                            } else {
                              _priorities.remove(priority);
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.save),
                  label: const Text('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanEditResult {
  const _PlanEditResult({
    required this.title,
    required this.weddingDate,
    required this.currency,
    required this.priorities,
    required this.location,
  });

  final String title;
  final DateTime? weddingDate;
  final String currency;
  final List<String> priorities;
  final WeddingLocationDraft? location;

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      if (weddingDate != null)
        'weddingDate': DateTime.utc(
          weddingDate!.year,
          weddingDate!.month,
          weddingDate!.day,
        ).toIso8601String(),
      'currency': currency,
      'priorities': priorities,
      if (location != null) ...{
        'city': location!.cityOrDistrict,
        'location': location!.toJson(),
      },
    };
  }
}

class _ManagementLoadError extends StatelessWidget {
  const _ManagementLoadError({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AarastErrorState(
          title: 'تعذر تحميل إدارة الخطة',
          message: message ?? 'لم يتم العثور على بيانات الخطة.',
          onRetry: onRetry,
        ),
      ],
    );
  }
}

String? _clean(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _supportedCurrency(String value) {
  final normalized = value.toUpperCase();
  return const {'YER', 'SAR', 'USD'}.contains(normalized) ? normalized : 'YER';
}
