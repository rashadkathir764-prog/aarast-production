import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../auth/providers/auth_controller.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../../marketplace/widgets/quote_status_chip.dart';
import '../../onboarding/models/wedding_location_draft.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../../shared/models/quote_finance_context.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import '../models/dashboard_summary.dart';
import '../models/wedding_plan.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';
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
  bool get _isLocalGuestPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLocalGuestPlan) return;
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      );
      _loadPlanQuotes();
    });
  }

  @override
  void didUpdateWidget(covariant PlanCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.sharedMember != widget.sharedMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isLocalGuestPlan) return;
        context.read<DashboardSummaryProvider>().loadDashboard(
          widget.weddingPlanId,
          sharedMember: widget.sharedMember,
        );
        _loadPlanQuotes();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();
    final plan = provider.plan;
    final hasCurrentPlan = plan?.id == widget.weddingPlanId;

    return AarastScreenFrame(
      maxWidth: 560,
      safeAreaBottom: false,
      bottomNavigationBar: _buildBottomNav(provider),
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: _isLocalGuestPlan
            ? () async {}
            : () async {
                await provider.loadDashboard(
                  widget.weddingPlanId,
                  sharedMember: widget.sharedMember,
                );
                await _readMarketplace()?.loadMyQuoteRequests();
              },
        child: _buildBody(provider, auth, hasCurrentPlan),
      ),
    );
  }

  Widget _buildBody(
    DashboardSummaryProvider provider,
    AuthController auth,
    bool hasCurrentPlan,
  ) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 118;

    if (_isLocalGuestPlan) {
      return _buildLocalPlanBody(bottomPadding, widget.initialSummary);
    }

    if (provider.isLoading && !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: const [
          _PlanCenterHeader(),
          SizedBox(height: 10),
          _PlanCenterLoading(),
        ],
      );
    }

    if (provider.errorMessage != null && !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: [
          const _PlanCenterHeader(),
          const SizedBox(height: 10),
          _PcCard(
            padding: const EdgeInsets.all(18),
            child: _PcEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل مركز الخطة',
              message: provider.errorMessage!,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: _pcOutlinedButtonStyle(),
            onPressed: () => provider.loadDashboard(
              widget.weddingPlanId,
              sharedMember: widget.sharedMember,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null || !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: const [
          _PlanCenterHeader(),
          SizedBox(height: 10),
          _PcCard(
            padding: EdgeInsets.all(18),
            child: _PcEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'لا توجد خطة',
              message: 'لم يتم العثور على بيانات الخطة الحالية.',
            ),
          ),
        ],
      );
    }

    final summary = provider.summary;
    final tasksAvailable = summary != null || provider.tasks != null;
    final tasks = provider.tasks ?? const <WeddingTask>[];
    final totalTasks = summary?.totalTasks ?? tasks.length;
    final completedTasks =
        summary?.completedTasks ?? tasks.where((task) => task.isDone).length;
    final remainingTasks = math.max(0, totalTasks - completedTasks);
    final progressPercent = tasksAvailable && totalTasks > 0
        ? ((completedTasks / totalTasks) * 100).round().clamp(0, 100)
        : tasksAvailable
        ? 0
        : null;
    final isOwner =
        auth.user?.id == plan.ownerUserId || widget.sharedMember == null;
    final canManagePlan = isOwner || widget.sharedMember?.role == 'MANAGER';
    final canOpenFinance =
        widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;
    final canOpenDebts =
        widget.sharedMember == null || widget.sharedMember!.canReadDebts;
    final canOpenSharing = widget.sharedMember == null;
    final activePlan = _maybeWatchWeddingPlans(context)?.activePlan;
    final personaCopy = activePlan?.id == plan.id
        ? personaCopyForBackend(activePlan?.persona)
        : null;
    final planLocation = activePlan?.id == plan.id
        ? activePlan!.weddingLocation
        : plan.weddingLocation;
    final roleLabel = personaCopy?.isKnown == true
        ? personaCopy!.identityLabel
        : _roleLabel(isOwner, widget.sharedMember);
    final marketplace = _watchMarketplace();
    final planQuotes =
        marketplace?.quotesForPlan(plan.id) ?? const <QuoteRequest>[];
    final hasPlanLocation = planLocation.hasAnyLocation;
    final hasPlanBudget = _hasBudget(plan, summary);
    final showTaskSetup = tasksAvailable && totalTasks == 0;
    final showGuestSetup = summary != null && summary.guestCount == 0;
    final showProviderSetup =
        summary != null &&
        summary.quoteRequestsCount == 0 &&
        summary.acceptedProviders == 0;
    final showSetupChecklist =
        !hasPlanLocation ||
        !hasPlanBudget ||
        showTaskSetup ||
        showGuestSetup ||
        showProviderSetup;

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      children: [
        const _PlanCenterHeader(),
        const SizedBox(height: 10),
        _PremiumPlanSummaryHero(
          plan: plan,
          progressPercent: progressPercent,
          completedTasks: completedTasks,
          totalTasks: tasksAvailable ? totalTasks : null,
          canManagePlan: canManagePlan,
          onEdit: () => _showEditPlanSheet(provider, plan),
        ),
        const SizedBox(height: 10),
        _PlanLocationCard(
          location: planLocation,
          canManagePlan: canManagePlan,
          onEdit: () => _showEditPlanSheet(provider, plan),
        ),
        const SizedBox(height: 10),
        if (showSetupChecklist)
          _SetupChecklistCard(
            showLocation: !hasPlanLocation,
            showBudget: !hasPlanBudget,
            showTasks: showTaskSetup,
            showGuests: showGuestSetup,
            showProviders: showProviderSetup,
            onTasks: () => context.push(AppRouter.tasks(plan.id)),
            onBudget: () => canOpenFinance
                ? _openFinanceOverview(provider, plan.id)
                : _showFinancialAccessDenied(),
            onGuests: () => context.push(AppRouter.guestList(plan.id)),
            onProviders: () => context.push(AppRouter.providerMarketplace),
            onEditPlan: () => _showEditPlanSheet(provider, plan),
          ),
        if (tasksAvailable && totalTasks > 0) ...[
          _ProgressSummaryCard(
            progressPercent: progressPercent,
            completedTasks: completedTasks,
            remainingTasks: remainingTasks,
            lastUpdate: plan.updatedAt,
          ),
          const SizedBox(height: 10),
        ],
        _PlanSectionsCard(
          onTasks: () => context.push(AppRouter.tasks(plan.id)),
          onBudget: canOpenFinance
              ? () => _openFinanceOverview(provider, plan.id)
              : _showFinancialAccessDenied,
          onDebts: canOpenDebts
              ? () => context.push(
                  AppRouter.debts(plan.id),
                  extra: widget.sharedMember,
                )
              : _showFinancialAccessDenied,
          onGuests: () => context.push(AppRouter.guestList(plan.id)),
          onProviders: () => context.push(AppRouter.providerMarketplace),
          onSharing: canOpenSharing
              ? () => context.push(AppRouter.sharing(plan.id))
              : () => _showUnavailable('إدارة المشاركة متاحة لصاحب الخطة فقط.'),
          sharingEnabled: canOpenSharing,
          budgetEnabled: canOpenFinance,
          debtsEnabled: canOpenDebts,
        ),
        const SizedBox(height: 10),
        _PlanQuotesCard(
          quotes: planQuotes,
          canManage: canManagePlan,
          isSubmitting: marketplace?.isSubmitting ?? false,
          onBrowseProviders: () => context.push(AppRouter.providerMarketplace),
          onAccept: marketplace == null
              ? null
              : (quote) async {
                  await marketplace.acceptQuote(quote);
                },
          onReject: marketplace == null
              ? null
              : (quote) async {
                  await marketplace.rejectQuote(quote);
                },
          onAddExpense: (quote) => context.push(
            AppRouter.createExpense(plan.id),
            extra: _quoteFinanceContext(quote),
          ),
          onAddDebt: (quote) => context.push(
            AppRouter.createDebt(plan.id),
            extra: _quoteFinanceContext(quote),
          ),
        ),
        const SizedBox(height: 10),
        _ParticipantsCard(
          roleLabel: roleLabel,
          participantsCount: provider.sharedMembers?.length,
          permissionsLabel: _permissionsLabel(isOwner, widget.sharedMember),
          canManageSharing: canOpenSharing,
          onManageSharing: () => context.push(AppRouter.sharing(plan.id)),
        ),
        const SizedBox(height: 10),
        _PlanSettingsCard(
          plan: plan,
          canManagePlan: canManagePlan,
          onEdit: () => _showEditPlanSheet(provider, plan),
          onArchive: () => _showArchivePlanSheet(provider, plan),
        ),
      ],
    );
  }

  ProviderMarketplaceProvider? _readMarketplace() {
    try {
      return context.read<ProviderMarketplaceProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  ProviderMarketplaceProvider? _watchMarketplace() {
    try {
      return context.watch<ProviderMarketplaceProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _loadPlanQuotes() {
    _readMarketplace()?.loadMyQuoteRequests();
  }

  QuoteFinanceContext _quoteFinanceContext(QuoteRequest quote) {
    final offer = quote.acceptedOffer ?? quote.pendingOffer;
    return QuoteFinanceContext(
      quoteRequestId: quote.id,
      providerId: quote.providerId,
      providerName:
          quote.provider?.businessName ??
          quote.service?.provider?.businessName ??
          'المورد',
      quoteOfferId: offer?.id,
      serviceTitle: quote.service?.title,
      amount: offer?.amount,
      currency: offer?.currency,
    );
  }

  Widget _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id == widget.weddingPlanId
        ? provider.plan!.id
        : widget.weddingPlanId;
    return RoyalDashboardBottomNav(
      activeIndex: 0,
      onHome: () => context.go(AppRouter.home),
      onMoney: () => context.push(AppRouter.finance(planId)),
      onTasks: () => context.push(AppRouter.tasks(planId)),
      onProviders: () => context.push(AppRouter.providerMarketplace),
      onMore: () => context.push(AppRouter.more),
    );
  }

  Future<void> _openFinanceOverview(
    DashboardSummaryProvider provider,
    String planId,
  ) async {
    final canOpenFinance =
        widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;
    if (!canOpenFinance) {
      _showFinancialAccessDenied();
      return;
    }

    final changed = await context.push<bool>(
      AppRouter.finance(planId),
      extra: widget.sharedMember,
    );
    if (changed != true || !mounted) return;
    await provider.loadDashboard(planId, sharedMember: widget.sharedMember);
  }

  Widget _buildLocalPlanBody(double bottomPadding, DashboardSummary? summary) {
    final planId = widget.weddingPlanId;
    final localPlan = summary?.toWeddingPlan();
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      children: [
        const _PlanCenterHeader(),
        const SizedBox(height: 10),
        if (localPlan != null) ...[
          _PremiumPlanSummaryHero(
            plan: localPlan,
            progressPercent: summary!.progressPercentage,
            completedTasks: summary.completedTasks,
            totalTasks: summary.totalTasks,
            canManagePlan: false,
            onEdit: () => _showUnavailable(
              'هذا الإجراء يحتاج تسجيل الدخول عند الحفظ النهائي.',
            ),
          ),
          const SizedBox(height: 10),
          _PlanLocationCard(
            location: localPlan.weddingLocation,
            canManagePlan: false,
            onEdit: () =>
                _showUnavailable('تحتاج لتسجيل الدخول لحفظ بيانات الخطة.'),
          ),
          const SizedBox(height: 10),
        ],
        _SetupChecklistCard(
          showLocation: localPlan?.weddingLocation.hasAnyLocation != true,
          showBudget: !_positiveMoney(
            summary?.budgetTotal ?? localPlan?.estimatedBudget,
          ),
          showTasks: (summary?.totalTasks ?? 0) == 0,
          showGuests: (summary?.guestCount ?? 0) == 0,
          showProviders:
              (summary?.quoteRequestsCount ?? 0) == 0 &&
              (summary?.acceptedProviders ?? 0) == 0,
          onTasks: () => context.push(AppRouter.tasks(planId)),
          onBudget: () => context.push(AppRouter.finance(planId)),
          onGuests: () => context.push(AppRouter.guestList(planId)),
          onProviders: () => context.push(AppRouter.providerMarketplace),
          onEditPlan: () =>
              _showUnavailable('تحتاج لتسجيل الدخول لحفظ بيانات الخطة.'),
        ),
        const SizedBox(height: 10),
        _PlanSectionsCard(
          onTasks: () => context.push(AppRouter.tasks(planId)),
          onBudget: () => context.push(AppRouter.finance(planId)),
          onDebts: () => context.push(AppRouter.debts(planId)),
          onGuests: () => context.push(AppRouter.guestList(planId)),
          onProviders: () => context.push(AppRouter.providerMarketplace),
          onSharing: () => _showUnavailable(
            'المشاركة تحتاج تسجيل الدخول عند الحفظ النهائي.',
          ),
          sharingEnabled: false,
          budgetEnabled: true,
          debtsEnabled: true,
        ),
        if (summary != null) ...[
          const SizedBox(height: 10),
          _ParticipantsCard(
            roleLabel: 'مسودة على الجهاز',
            participantsCount: 1,
            permissionsLabel: 'لم تتم المزامنة بعد',
            canManageSharing: false,
            onManageSharing: () => _showUnavailable(
              'المشاركة تحتاج تسجيل الدخول عند الحفظ النهائي.',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showEditPlanSheet(
    DashboardSummaryProvider dashboardProvider,
    WeddingPlan plan,
  ) async {
    final result = await showModalBottomSheet<_PlanEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _EditPlanSheet(plan: plan),
    );

    if (result == null || !mounted) return;

    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final updated = await weddingPlansProvider.updateWeddingPlan(
      plan.id,
      result.toUpdateJson(),
    );
    if (!mounted) return;
    if (updated != null) {
      await dashboardProvider.loadDashboard(
        plan.id,
        sharedMember: widget.sharedMember,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم تحديث الخطة.')));
      return;
    }

    final error = weddingPlansProvider.errorMessage;
    if (error != null) _showUnavailable(error);
  }

  Future<void> _showArchivePlanSheet(
    DashboardSummaryProvider dashboardProvider,
    WeddingPlan plan,
  ) async {
    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'أرشفة الخطة؟',
                    style: TextStyle(
                      color: _pcInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم نقل "${plan.title}" إلى الأرشيف بدون حذف البيانات.',
                    style: const TextStyle(
                      color: _pcMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('أرشفة'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final archived = await weddingPlansProvider.archiveWeddingPlan(plan.id);
    if (archived != null && mounted) {
      await dashboardProvider.loadDashboard(
        plan.id,
        sharedMember: widget.sharedMember,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تمت أرشفة الخطة.')));
    } else {
      final error = weddingPlansProvider.errorMessage;
      if (error != null && mounted) _showUnavailable(error);
    }
  }

  void _showFinancialAccessDenied() {
    _showUnavailable(
      'هذا القسم غير متاح حسب صلاحياتك ولا يتم عرض البيانات المالية الخاصة.',
    );
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  WeddingPlansProvider? _maybeWatchWeddingPlans(BuildContext context) {
    try {
      return context.watch<WeddingPlansProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _EditPlanSheet extends StatefulWidget {
  const _EditPlanSheet({required this.plan});

  final WeddingPlan plan;

  @override
  State<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends State<_EditPlanSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _cityController;
  late DateTime? _selectedDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan.title);
    _cityController = TextEditingController(text: widget.plan.city ?? '');
    _selectedDate = widget.plan.weddingDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'اسم الخطة مطلوب');
      return;
    }

    setState(() => _errorMessage = null);
    Navigator.of(context).pop(
      _PlanEditResult(
        title: title,
        city: _cityController.text.trim(),
        weddingDate: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _pcLine,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تعديل بيانات الخطة',
                  style: TextStyle(
                    color: _pcInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخطة',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'المدينة',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: _pcOutlinedButtonStyle(),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _selectedDate == null
                        ? 'اختيار تاريخ الزواج'
                        : _dateLabel(_selectedDate),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ التعديل'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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
    required this.city,
    required this.weddingDate,
  });

  final String title;
  final String city;
  final DateTime? weddingDate;

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'city': city,
      if (weddingDate != null) 'weddingDate': _dateOnlyIso(weddingDate!),
    };
  }
}

String _dateOnlyIso(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day).toIso8601String();
}

class _PlanCenterHeader extends StatelessWidget {
  const _PlanCenterHeader();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 78),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRouter.home);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'مركز الخطة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _pcInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.calendar_month_outlined,
                      color: _pcInk,
                      size: 23,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'تفاصيل الخطة الحالية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _pcMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PremiumPlanSummaryHero extends StatelessWidget {
  const _PremiumPlanSummaryHero({
    required this.plan,
    required this.progressPercent,
    required this.completedTasks,
    required this.totalTasks,
    required this.canManagePlan,
    required this.onEdit,
  });

  final WeddingPlan plan;
  final int? progressPercent;
  final int completedTasks;
  final int? totalTasks;
  final bool canManagePlan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B001A),
            _RoyalColors.burgundy,
            _RoyalColors.burgundyDark,
          ],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _RoyalColors.gold.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _RoyalColors.burgundy.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _RoyalColors.gold.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _RoyalColors.burgundyLight.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _RoyalColors.gold,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildHeroMetaRow(
                              Icons.calendar_month_rounded,
                              _dateLabel(plan.weddingDate),
                            ),
                            const SizedBox(height: 6),
                            _buildHeroMetaRow(
                              Icons.location_on_rounded,
                              _cityLabel(
                                plan.weddingLocation.shortLabel ?? plan.city,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (progressPercent != null)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progressPercent! / 100,
                                strokeWidth: 5,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                color: _RoyalColors.gold,
                              ),
                              Text(
                                '$progressPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildTimeRemainingCard()),
                      if (canManagePlan) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRemainingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: _RoyalColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            _daysRemainingLabel(plan.daysRemaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({
    required this.progressPercent,
    required this.completedTasks,
    required this.remainingTasks,
    required this.lastUpdate,
  });

  final int? progressPercent;
  final int? completedTasks;
  final int? remainingTasks;
  final DateTime lastUpdate;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'ملخص التقدم',
            icon: Icons.donut_large_rounded,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _MetricTile(
                icon: Icons.donut_large_rounded,
                label: 'نسبة الإنجاز',
                value: progressPercent == null
                    ? 'غير متاح'
                    : '$progressPercent%',
              ),
              _MetricTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'المكتملة',
                value: completedTasks?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.description_outlined,
                label: 'المتبقية',
                value: remainingTasks?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.event_available_outlined,
                label: 'آخر تحديث',
                value: _lastUpdateLabel(lastUpdate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupChecklistCard extends StatelessWidget {
  const _SetupChecklistCard({
    required this.showLocation,
    required this.showBudget,
    required this.showTasks,
    required this.showGuests,
    required this.showProviders,
    required this.onTasks,
    required this.onBudget,
    required this.onGuests,
    required this.onProviders,
    required this.onEditPlan,
  });

  final bool showLocation;
  final bool showBudget;
  final bool showTasks;
  final bool showGuests;
  final bool showProviders;
  final VoidCallback onTasks;
  final VoidCallback onBudget;
  final VoidCallback onGuests;
  final VoidCallback onProviders;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final items = <_ChecklistItemData>[
      if (showLocation)
        _ChecklistItemData(
          icon: Icons.location_on_outlined,
          title: 'أكمل موقع الزفاف',
          subtitle:
              'تحديد المدينة يساعد في تصفية الموردين وتوضيح طلبات الأسعار.',
          onTap: onEditPlan,
        ),
      if (showBudget)
        _ChecklistItemData(
          icon: Icons.account_balance_wallet_outlined,
          title: 'حدد ميزانية الخطة',
          subtitle: 'أضف ميزانية حقيقية لعرض المتبقي والمصروف بدقة.',
          onTap: onBudget,
        ),
      if (showTasks)
        _ChecklistItemData(
          icon: Icons.check_box_outlined,
          title: 'أضف أول مهمة',
          subtitle: 'رتب أفكارك وابدأ بإنجاز المهام.',
          onTap: onTasks,
        ),
      if (showGuests)
        _ChecklistItemData(
          icon: Icons.person_add_alt_1_outlined,
          title: 'أضف أول ضيف',
          subtitle: 'تجهيز قائمة المدعوين يساعدك على تقدير التكلفة.',
          onTap: onGuests,
        ),
      if (showProviders)
        _ChecklistItemData(
          icon: Icons.storefront_outlined,
          title: 'استكشف الموردين',
          subtitle: 'تصفح القاعات والخدمات واطلب عرض سعر عند الحاجة.',
          onTap: onProviders,
        ),
    ];

    return _PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _RoyalColors.burgundyLight.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: _RoyalColors.burgundyLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك في خطتك الجديدة! 🎉',
                      style: TextStyle(
                        color: _pcInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'خطوات بسيطة للبدء بتجهيز يومك الكبير.',
                      style: TextStyle(
                        color: _pcMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++)
            _ChecklistItem(
              icon: items[i].icon,
              title: items[i].title,
              subtitle: items[i].subtitle,
              onTap: items[i].onTap,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ChecklistItemData {
  const _ChecklistItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _pcLine, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _RoyalColors.goldDeep, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _pcInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _pcMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: _pcMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlanSectionsCard extends StatelessWidget {
  const _PlanSectionsCard({
    required this.onTasks,
    required this.onBudget,
    required this.onDebts,
    required this.onGuests,
    required this.onProviders,
    required this.onSharing,
    required this.sharingEnabled,
    required this.budgetEnabled,
    required this.debtsEnabled,
  });

  final VoidCallback onTasks;
  final VoidCallback onBudget;
  final VoidCallback onDebts;
  final VoidCallback onGuests;
  final VoidCallback onProviders;
  final VoidCallback onSharing;
  final bool sharingEnabled;
  final bool budgetEnabled;
  final bool debtsEnabled;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'أقسام الخطة',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 300 ? 2 : 3;
              final itemWidth =
                  (constraints.maxWidth - (8 * (columns - 1))) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.assignment_outlined,
                      label: 'المهام',
                      onTap: onTasks,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'الميزانية',
                      onTap: onBudget,
                      enabled: budgetEnabled,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.savings_outlined,
                      label: 'الديون',
                      onTap: onDebts,
                      enabled: debtsEnabled,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.groups_2_outlined,
                      label: 'الضيوف',
                      onTap: onGuests,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.storefront_outlined,
                      label: 'الموردون',
                      onTap: onProviders,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.group_add_outlined,
                      label: 'المشاركة',
                      onTap: onSharing,
                      enabled: sharingEnabled,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanLocationCard extends StatelessWidget {
  const _PlanLocationCard({
    required this.location,
    required this.canManagePlan,
    required this.onEdit,
  });

  final WeddingLocationDraft location;
  final bool canManagePlan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location.hasAnyLocation;
    final street = location.street?.trim() ?? '';
    final detailedAddress = location.detailedAddress?.trim() ?? '';
    final hasStreet = street.isNotEmpty;
    final hasDetailedAddress = detailedAddress.isNotEmpty;
    final hasOptionalAddressGap =
        hasLocation && (!hasStreet || !hasDetailedAddress);
    final headline =
        location.fullLabel ??
        location.mediumLabel ??
        location.shortLabel ??
        'لم يضف موقع الزفاف بعد';

    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'موقع الزفاف',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasLocation
                  ? _RoyalColors.gold.withValues(alpha: 0.08)
                  : _pcMuted.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(_pcRadius),
              border: Border.all(color: _pcLine, width: 0.9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.add_location_alt_outlined,
                  color: hasLocation ? _RoyalColors.goldDeep : _pcMuted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headline,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasLocation ? _pcInk : _pcMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LocationDetailRow(
            label: 'المحافظة',
            value: _locationValue(location.governorate, 'غير محددة'),
          ),
          _LocationDetailRow(
            label: 'المدينة / المديرية',
            value: _locationValue(location.cityOrDistrict, 'غير محددة'),
          ),
          _LocationDetailRow(
            label: 'الحي / المنطقة',
            value: _locationValue(location.areaOrNeighborhood, 'لم يضف بعد'),
          ),
          if (hasStreet) _LocationDetailRow(label: 'الشارع', value: street),
          if (hasDetailedAddress)
            _LocationDetailRow(
              label: 'العنوان التفصيلي',
              value: detailedAddress,
            ),
          if (canManagePlan) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                style: _pcOutlinedButtonStyle(),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(
                  hasOptionalAddressGap
                      ? 'أكمل العنوان التفصيلي'
                      : 'تعديل بيانات الخطة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  const _LocationDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: _pcMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _pcText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanQuotesCard extends StatelessWidget {
  const _PlanQuotesCard({
    required this.quotes,
    required this.canManage,
    required this.isSubmitting,
    required this.onBrowseProviders,
    required this.onAccept,
    required this.onReject,
    required this.onAddExpense,
    required this.onAddDebt,
  });

  final List<QuoteRequest> quotes;
  final bool canManage;
  final bool isSubmitting;
  final VoidCallback onBrowseProviders;
  final Future<void> Function(QuoteRequest quote)? onAccept;
  final Future<void> Function(QuoteRequest quote)? onReject;
  final void Function(QuoteRequest quote) onAddExpense;
  final void Function(QuoteRequest quote) onAddDebt;

  @override
  Widget build(BuildContext context) {
    final visible = quotes.take(4).toList(growable: false);
    return _PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined, color: _pcInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الموردون والعروض',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _pcInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onBrowseProviders,
                child: const Text('تصفح الموردين'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const _PcEmptyState(
              icon: Icons.request_quote_outlined,
              title: 'لا توجد طلبات عروض بعد',
              message:
                  'عند طلب عرض سعر سيظهر هنا، ثم يمكنك قبول العرض أو رفضه من الخطة.',
            )
          else
            for (final quote in visible) ...[
              _PlanQuoteRow(
                quote: quote,
                canManage: canManage,
                isSubmitting: isSubmitting,
                onAccept: onAccept,
                onReject: onReject,
                onAddExpense: onAddExpense,
                onAddDebt: onAddDebt,
              ),
              if (quote != visible.last)
                const Divider(height: 22, color: _pcLine),
            ],
        ],
      ),
    );
  }
}

class _PlanQuoteRow extends StatelessWidget {
  const _PlanQuoteRow({
    required this.quote,
    required this.canManage,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
    required this.onAddExpense,
    required this.onAddDebt,
  });

  final QuoteRequest quote;
  final bool canManage;
  final bool isSubmitting;
  final Future<void> Function(QuoteRequest quote)? onAccept;
  final Future<void> Function(QuoteRequest quote)? onReject;
  final void Function(QuoteRequest quote) onAddExpense;
  final void Function(QuoteRequest quote) onAddDebt;

  @override
  Widget build(BuildContext context) {
    final offer = quote.pendingOffer ?? quote.acceptedOffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                quote.provider?.businessName ??
                    quote.service?.title ??
                    'طلب عرض سعر',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _pcInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
          ],
        ),
        if (offer?.amount?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            '${offer!.amount} ${offer.currency ?? 'YER'}',
            style: const TextStyle(
              color: _pcMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (quote.canAcceptOrReject && canManage) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isSubmitting || onAccept == null
                    ? null
                    : () => onAccept!(quote),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('قبول العرض'),
              ),
              OutlinedButton(
                onPressed: isSubmitting || onReject == null
                    ? null
                    : () => onReject!(quote),
                child: const Text('رفض العرض'),
              ),
            ],
          ),
        ],
        if (quote.lifecycleStatus == 'ACCEPTED' && canManage) ...[
          const SizedBox(height: 10),
          const Text(
            'يمكنك تسجيل المبلغ كمصروف أو كدين لاحقًا، أو تجاهل هذه الخطوة الآن. لن يُنشأ أي سجل تلقائيًا.',
            style: TextStyle(
              color: _pcMuted,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onAddExpense(quote),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('إضافة كمصروف'),
              ),
              OutlinedButton.icon(
                onPressed: () => onAddDebt(quote),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                label: const Text('إضافة كدين / دفعة لاحقة'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({
    required this.roleLabel,
    required this.participantsCount,
    required this.permissionsLabel,
    required this.canManageSharing,
    required this.onManageSharing,
  });

  final String roleLabel;
  final int? participantsCount;
  final String permissionsLabel;
  final bool canManageSharing;
  final VoidCallback onManageSharing;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'المشاركون والصلاحيات',
            icon: Icons.people_outline_rounded,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _MetricTile(
                icon: Icons.person_outline_rounded,
                label: 'الدور',
                value: roleLabel,
              ),
              _MetricTile(
                icon: Icons.groups_outlined,
                label: 'المشاركون',
                value: participantsCount?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.verified_user_outlined,
                label: 'الصلاحيات',
                value: permissionsLabel,
              ),
            ],
          ),
          if (canManageSharing) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                style: _pcOutlinedButtonStyle(),
                onPressed: onManageSharing,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text(
                  'إدارة المشاركة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({
    required this.plan,
    required this.canManagePlan,
    required this.onEdit,
    required this.onArchive,
  });

  final WeddingPlan plan;
  final bool canManagePlan;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final disabledSubtitle = canManagePlan ? null : 'يتطلب صلاحية إدارة الخطة';
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'إعدادات الخطة',
            icon: Icons.settings_outlined,
          ),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.edit_outlined,
            title: 'تغيير اسم الخطة',
            subtitle: disabledSubtitle ?? plan.title,
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.calendar_month_outlined,
            title: 'تغيير تاريخ الزواج',
            subtitle: disabledSubtitle ?? _dateLabel(plan.weddingDate),
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.location_on_outlined,
            title: 'تغيير المدينة / الموقع',
            subtitle:
                disabledSubtitle ??
                _cityLabel(plan.weddingLocation.shortLabel ?? plan.city),
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.archive_outlined,
            title: 'أرشفة الخطة',
            subtitle: canManagePlan
                ? 'نقلها للأرشيف بدون حذف البيانات'
                : disabledSubtitle!,
            enabled: canManagePlan && plan.status != 'ARCHIVED',
            onTap: onArchive,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine, width: 0.9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _pcInk, size: 20),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pcText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 280 ? 1 : 2;
        final itemWidth =
            (constraints.maxWidth - (8 * (columns - 1))) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _pcInk : _pcMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _pcText : _pcMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _pcLine, width: 0.8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _pcMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.chevron_left_rounded : Icons.lock_outline_rounded,
              color: _pcMuted,
              size: enabled ? 20 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _PcCard extends StatelessWidget {
  const _PcCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine.withValues(alpha: 0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _pcInk.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _PcSectionTitle extends StatelessWidget {
  const _PcSectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _pcInk, size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _PcEmptyState extends StatelessWidget {
  const _PcEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _pcMuted, size: 34),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _pcInk,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _pcMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlanCenterLoading extends StatelessWidget {
  const _PlanCenterLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonBox(height: 170),
        SizedBox(height: 10),
        _SkeletonBox(height: 124),
        SizedBox(height: 10),
        _SkeletonBox(height: 132),
        SizedBox(height: 10),
        _SkeletonBox(height: 112),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _pcSoft,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine),
      ),
    );
  }
}

const _pcInk = AppTheme.dInk;
const _pcText = AppTheme.charcoal;
const _pcMuted = AppTheme.dMuted;
const _pcLine = AppTheme.dLine;
const _pcSoft = AppTheme.dCard;
const _pcRadius = 16.0;

class _RoyalColors {
  const _RoyalColors._();

  static const burgundy = AppTheme.deepBurgundy;
  static const burgundyDark = AppTheme.dMaroonDeep;
  static const burgundyLight = AppTheme.dMaroonBright;
  static const gold = AppTheme.warmGold;
  static const goldDeep = AppTheme.dGoldDeep;
}

ButtonStyle _pcOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _pcInk,
    disabledForegroundColor: _pcMuted,
    side: const BorderSide(color: _pcInk, width: 0.8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
  );
}

bool _hasBudget(WeddingPlan plan, DashboardSummary? summary) {
  return _positiveMoney(summary?.budgetTotal) ||
      _positiveMoney(plan.estimatedBudget);
}

bool _positiveMoney(String? value) {
  if (value == null) return false;
  final parsed = double.tryParse(value.trim());
  return parsed != null && parsed > 0;
}

String _dateLabel(DateTime? date) {
  return date == null ? 'غير محدد' : dashFormatArDate(date);
}

String _cityLabel(String? city) {
  return city?.trim().isNotEmpty == true ? city!.trim() : 'غير محددة';
}

String _locationValue(String? value, String fallback) {
  return value?.trim().isNotEmpty == true ? value!.trim() : fallback;
}

String _daysRemainingLabel(int? days) {
  if (days == null) return 'غير محدد';
  if (days < 0) return 'انتهى الموعد';
  if (days == 0) return 'اليوم';
  return 'باقي $days يوم';
}

String _lastUpdateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final updateDay = DateTime(date.year, date.month, date.day);
  if (updateDay == today) return 'اليوم';
  return dashFormatArDate(date);
}

String _roleLabel(bool isOwner, SharedMember? member) {
  if (isOwner) return 'صاحب';
  if (member == null) return 'غير متاح';
  return 'مشارك: ${sharedMemberRoleLabel(member.role)}';
}

String _permissionsLabel(bool isOwner, SharedMember? member) {
  if (isOwner) return 'كاملة';
  if (member == null) return 'غير متاح';
  if (member.permissionLabels.isEmpty) return 'مهام فقط';
  return member.permissionLabels.take(2).join('، ');
}
