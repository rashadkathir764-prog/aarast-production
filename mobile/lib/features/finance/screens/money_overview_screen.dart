import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingProvider, GuestPersona;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        DashboardSummaryProvider,
        WeddingPlansProvider,
        WeddingStageContextLine,
        WeddingStageDomain,
        resolveWeddingPlanStage;
import '../models/money_summary.dart';
import '../models/money_starter_catalog.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/funding_widgets.dart';
import '../widgets/money_starter_setup.dart';
import '../widgets/money_widgets.dart';

/// نقطة الدخول الوحيدة للمال.
///
/// تعرض ملخص MoneySummary ثم قائمة WeddingCost. تبقى حركات الدفع داخل تفاصيل
/// التكلفة، بينما تُفتح الميزانية ومواعيد الدفع في شاشاتهما المتخصصة.
class MoneyOverviewScreen extends StatefulWidget {
  const MoneyOverviewScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    this.personaCode,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;
  final String? personaCode;

  @override
  State<MoneyOverviewScreen> createState() => _MoneyOverviewScreenState();
}

class _MoneyOverviewScreenState extends State<MoneyOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MoneyOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final dashboardSummary = context
        .watch<DashboardSummaryProvider?>()
        ?.summary;
    final stage = dashboardSummary?.planId == widget.weddingPlanId
        ? resolveWeddingPlanStage(dashboardSummary?.weddingDate)
        : null;
    final bottomClearance = widget.embedded && provider.canManageMoney
        ? 204.0
        : 132.0;
    final Widget content;
    if (provider.isLoading && !provider.hasLoadedMoney) {
      content = _MoneyRootStateList(
        bottomClearance: bottomClearance,
        child: const AarastScreenLoading(label: 'نرتب صورتك المالية'),
      );
    } else if (provider.errorMessage != null && !provider.hasLoadedMoney) {
      content = _MoneyRootStateList(
        bottomClearance: bottomClearance,
        child: AarastErrorState(
          title: 'تعذر تحميل المال',
          message: provider.errorMessage!,
          onRetry: _load,
        ),
      );
    } else if (shouldShowMoneyStarter(provider)) {
      final persona = _starterPersona(context);
      final managedCatalog = context
          .watch<ReferenceCatalogProvider?>()
          ?.catalogFor('money.starter.categories');
      content = MoneyStarterSetup(
        catalog: moneyStarterCatalogFromManaged(managedCatalog, persona),
        loading: provider.isSubmitting,
        errorMessage: provider.errorMessage,
        embedded: widget.embedded,
        onRefresh: _load,
        onManualSetup: () =>
            context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
        onSubmit: _saveStarterCategories,
      );
    } else {
      content = RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey('money-overview-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomClearance),
          children: [
            if (provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 14),
            ],
            _MoneySnapshot(
              summary: provider.summary,
              canManage: provider.canManageMoney,
              amountsHidden: provider.amountsHidden,
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              onSchedules: () =>
                  context.push(AppRouter.moneySchedules(widget.weddingPlanId)),
            ),
            // Field test Q03: an overspent category must be visible the moment
            // the money screen shows it, not only in the hourly notification.
            for (final exceeded in provider.summary.exceededCategories) ...[
              const SizedBox(height: 12),
              MoneyMessageBanner(
                key: ValueKey('money-category-exceeded-${exceeded.name}'),
                error: true,
                message: provider.amountsHidden || exceeded.overrun == null
                    ? 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له.'
                    : 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له بـ ${formatCompactMoney(moneyValue(exceeded.overrun), currencyCode: provider.summary.currency)}.',
              ),
            ],
            if (stage != null) ...[
              const SizedBox(height: 12),
              WeddingStageContextLine(
                stage: stage,
                domain: WeddingStageDomain.money,
              ),
            ],
            if (_nextSchedule(provider) case final schedule?) ...[
              const SizedBox(height: 14),
              _NextPaymentCard(
                schedule: schedule,
                currency: provider.summary.currency,
                onTap: () => context.push(
                  AppRouter.moneyScheduleDetails(
                    widget.weddingPlanId,
                    schedule.costId,
                    schedule.id,
                  ),
                ),
                onPay: _payableCost(provider, schedule) == null
                    ? null
                    : () => _paySchedule(
                        schedule,
                        _payableCost(provider, schedule)!,
                      ),
              ),
            ],
            // Only the plan owner receives funding in the summary.
            if (provider.summary.funding case final funding?) ...[
              const SizedBox(height: 14),
              MoneyFundingCard(
                funding: funding,
                currency: provider.summary.currency,
                onOpen: () =>
                    context.push(AppRouter.moneyFunding(widget.weddingPlanId)),
              ),
            ],
            const SizedBox(height: 24),
            _MoneyCostsSection(
              costs: provider.costs,
              currency: provider.summary.currency,
              canManage: provider.canManageMoney,
              hasBudget: provider.summary.hasBudget,
              hasMore: provider.hasMoreCosts,
              categoryName: (cost) =>
                  provider.categoryById(cost.budgetCategoryId)?.name ??
                  cost.categoryName,
              onAdd: () =>
                  context.push(AppRouter.moneyCostCreate(widget.weddingPlanId)),
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              onAll: () =>
                  context.push(AppRouter.moneyCosts(widget.weddingPlanId)),
              onOpen: (cost) => context.push(
                AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.embedded) {
      return ColoredBox(
        key: const ValueKey('money-overview-surface'),
        color: AppTheme.canvas,
        child: Directionality(textDirection: TextDirection.rtl, child: content),
      );
    }
    return AarastScreenFrame(maxWidth: 560, child: content);
  }

  MoneyStarterPersona _starterPersona(BuildContext context) {
    final explicit = widget.personaCode;
    if (explicit != null) return moneyStarterPersonaFromCode(explicit);

    final accountContext = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    if (accountContext?.weddingPlanId == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(accountContext?.persona?.name);
    }

    final plans = context.watch<WeddingPlansProvider?>();
    final activePlan = plans?.activePlan;
    if (activePlan?.id == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(activePlan?.persona);
    }
    final selectedPlan = plans?.selectedPlan;
    if (selectedPlan?.id == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(selectedPlan?.persona);
    }

    final localDraft = context.watch<GuestOnboardingProvider?>()?.draft;
    if (localDraft?.guestPlanId == widget.weddingPlanId) {
      return switch (localDraft?.persona) {
        GuestPersona.groom => MoneyStarterPersona.groom,
        GuestPersona.bride => MoneyStarterPersona.bride,
        _ => MoneyStarterPersona.neutral,
      };
    }
    return MoneyStarterPersona.neutral;
  }

  Future<bool> _saveStarterCategories(List<String> categoryNames) async {
    if (categoryNames.isEmpty) return false;
    final provider = context.read<FinanceProvider>();
    final saved = await provider.saveBudget(
      planId: widget.weddingPlanId,
      totalBudget: provider.summary.budget.total,
      currency: provider.summary.currency,
      categories: [
        for (final name in categoryNames)
          (id: null, name: name, allocatedAmount: null),
      ],
    );
    if (!saved || !mounted) return false;

    AarastToast.showSuccess(
      context,
      provider.summary.hasBudget
          ? 'جهّزنا ${categoryNames.length} تصنيفًا. وزّع ميزانيتك عليها.'
          : 'جهّزنا ${categoryNames.length} تصنيفًا. بقي تحديد ميزانيتك.',
    );
    await context.push(AppRouter.moneyBudget(widget.weddingPlanId));
    return true;
  }

  PaymentSchedule? _nextSchedule(FinanceProvider provider) {
    return provider.summary.paymentSchedules.next ??
        (provider.dueSchedules.isEmpty ? null : provider.dueSchedules.first);
  }

  WeddingCost? _payableCost(
    FinanceProvider provider,
    PaymentSchedule schedule,
  ) {
    final cost = provider.costById(schedule.costId);
    return provider.canManageMoney &&
            schedule.isPending &&
            cost != null &&
            !cost.isCancelled
        ? cost
        : null;
  }

  Future<void> _paySchedule(PaymentSchedule schedule, WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(widget.weddingPlanId, cost.id, schedule.id),
      extra: schedule,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _load() {
    final member = widget.sharedMember;
    final futures = <Future<void>>[
      context.read<FinanceProvider>().loadMoney(
        widget.weddingPlanId,
        canViewMoney: member?.canViewMoney ?? true,
        canManageMoney: member?.canManageMoney ?? true,
      ),
    ];
    final catalogs = context.read<ReferenceCatalogProvider?>();
    if (catalogs != null) futures.add(catalogs.load(refresh: true));
    return Future.wait(futures);
  }
}

bool shouldShowMoneyStarter(FinanceProvider provider) {
  if (!provider.hasLoadedMoney || !provider.canManageMoney) return false;
  final summary = provider.summary;
  // A budget alone (usually entered while creating the plan) is not a money
  // setup: the starter is what turns it into categories, and saving it keeps
  // the budget.
  return provider.categories.isEmpty &&
      provider.costs.isEmpty &&
      provider.payments.isEmpty &&
      provider.dueSchedules.isEmpty &&
      summary.costs.count == 0 &&
      summary.paymentSchedules.totalCount == 0;
}

class _MoneyRootStateList extends StatelessWidget {
  const _MoneyRootStateList({
    required this.child,
    required this.bottomClearance,
  });

  final Widget child;
  final double bottomClearance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomClearance),
      children: [child],
    );
  }
}

enum _MoneySettingsAction { budget, schedules }

class _MoneyCostsSection extends StatelessWidget {
  const _MoneyCostsSection({
    required this.costs,
    required this.currency,
    required this.canManage,
    required this.hasBudget,
    required this.hasMore,
    required this.categoryName,
    required this.onAdd,
    required this.onBudget,
    required this.onAll,
    required this.onOpen,
  });

  final List<WeddingCost> costs;
  final String currency;
  final bool canManage;
  final bool hasBudget;
  final bool hasMore;
  final String? Function(WeddingCost cost) categoryName;
  final VoidCallback onAdd;
  final VoidCallback onBudget;
  final VoidCallback onAll;
  final ValueChanged<WeddingCost> onOpen;

  @override
  Widget build(BuildContext context) {
    final visibleCosts = costs.take(3).toList(growable: false);
    final shouldShowAll = hasMore || costs.length > visibleCosts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'التكاليف',
          subtitle: costs.isEmpty
              ? 'سجّل كل خدمة ومبلغها في بطاقة واحدة.'
              : '${_costCountLabel(costs.length)} مسجلة في الخطة.',
          icon: LucideIcons.receipt,
        ),
        const SizedBox(height: 10),
        if (costs.isEmpty)
          AarastEmptyState(
            icon: LucideIcons.receipt,
            title: 'لا توجد تكاليف بعد',
            message: canManage
                ? 'يمكنك إضافة تكلفة الآن حتى لو لم تحدد الميزانية.'
                : 'لم تُسجل تكاليف في هذه الخطة حتى الآن.',
            action: canManage
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('money-empty-add-cost'),
                        onPressed: onAdd,
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('إضافة تكلفة'),
                      ),
                      if (!hasBudget)
                        TextButton(
                          onPressed: onBudget,
                          child: const Text('تحديد الميزانية'),
                        ),
                    ],
                  )
                : null,
          )
        else ...[
          for (var index = 0; index < visibleCosts.length; index++) ...[
            CostCard(
              key: ValueKey('money-overview-cost-${visibleCosts[index].id}'),
              cost: visibleCosts[index],
              currency: currency,
              categoryName: categoryName(visibleCosts[index]),
              onTap: () => onOpen(visibleCosts[index]),
            ),
            if (index != visibleCosts.length - 1) const SizedBox(height: 2),
          ],
          if (shouldShowAll) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAll,
              icon: const Icon(LucideIcons.arrowLeft, size: 17),
              label: const Text('عرض كل التكاليف'),
            ),
          ],
        ],
      ],
    );
  }
}

class _MoneySnapshot extends StatelessWidget {
  const _MoneySnapshot({
    required this.summary,
    required this.canManage,
    required this.amountsHidden,
    required this.onBudget,
    required this.onSchedules,
  });

  final MoneySummary summary;
  final bool canManage;
  final bool amountsHidden;
  final VoidCallback onBudget;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    final remaining = moneyValue(summary.budget.remaining);
    final progress = summary.confirmedRatio.clamp(0.0, 1.0).toDouble();
    final percent = (summary.confirmedRatio * 100).round();
    final overBudget = summary.hasBudget && remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('money-dashboard-hero'),
          padding: const EdgeInsets.all(AarastV3Space.x4),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.walletCards,
                    size: 19,
                    color: AarastV3Color.primary,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      summary.hasBudget
                          ? overBudget
                                ? 'فوق الميزانية'
                                : 'المتاح من الميزانية'
                          : 'الميزانية غير محددة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AarastV3Type.label(context).copyWith(
                        color: overBudget
                            ? AarastV3Color.rose
                            : AarastV3Color.primary,
                      ),
                    ),
                  ),
                  MoneyPrivacyButton(),
                  const SizedBox(width: AarastV3Space.x1),
                  _MoneySettingsMenu(
                    canManage: canManage,
                    onBudget: onBudget,
                    onSchedules: onSchedules,
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              if (!summary.hasBudget)
                Text(
                  'حدد ميزانيتك لنحسب المتاح ونرتب التكاليف بوضوح.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AarastV3Color.textMuted,
                    height: 1.4,
                  ),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: MoneyAmountText(
                          amount: remaining.abs(),
                          currency: summary.currency,
                          color: overBudget
                              ? AarastV3Color.rose
                              : AarastV3Color.ink,
                          style: AarastV3Type.display(
                            context,
                          ).copyWith(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Text(
                      amountsHidden ? '••' : '$percent%',
                      style: AarastV3Type.section(context).copyWith(
                        color: overBudget
                            ? AarastV3Color.rose
                            : AarastV3Color.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x2),
                AarastV3ProgressLine(
                  value: progress,
                  color: overBudget
                      ? AarastV3Color.rose
                      : AarastV3Color.primary,
                ),
                const SizedBox(height: AarastV3Space.x3),
                Row(
                  children: [
                    _LedgerMetric(
                      label: 'الميزانية',
                      amount: summary.budget.total,
                      currency: summary.currency,
                    ),
                    const _LedgerDivider(),
                    _LedgerMetric(
                      label: 'دُفع فعليًا',
                      amount: summary.costs.paid,
                      currency: summary.currency,
                      color: AarastV3Color.mint,
                    ),
                    const _LedgerDivider(),
                    _LedgerMetric(
                      label: 'غير مدفوع',
                      amount: summary.costs.outstanding,
                      currency: summary.currency,
                      color: AarastV3Color.primary,
                    ),
                  ],
                ),
              ],
              if (amountsHidden || !canManage) ...[
                const SizedBox(height: AarastV3Space.x3),
                AarastV3TrustLine(
                  icon: amountsHidden ? LucideIcons.eyeOff : LucideIcons.lock,
                  message: amountsHidden
                      ? 'الأرقام مخفية على هذه الشاشة لحماية خصوصيتك.'
                      : 'يمكنك الاطلاع على المال، والتعديل متاح لمدير الخطة فقط.',
                  tone: amountsHidden
                      ? AarastV3AttentionTone.calm
                      : AarastV3AttentionTone.information,
                ),
              ],
            ],
          ),
        ),
        if (!summary.hasBudget && canManage) ...[
          const SizedBox(height: AppTheme.space12),
          FilledButton.icon(
            key: const ValueKey('money-budget-setup'),
            onPressed: onBudget,
            icon: const Icon(LucideIcons.sparkles),
            label: const Text('بناء الميزانية'),
          ),
        ],
      ],
    );
  }
}

class _LedgerMetric extends StatelessWidget {
  const _LedgerMetric({
    required this.label,
    required this.amount,
    required this.currency,
    this.color = AarastV3Color.ink,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyAmountText(
              amount: amount,
              currency: currency,
              color: color,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: AarastV3Type.displayFamily,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastV3Color.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerDivider extends StatelessWidget {
  const _LedgerDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AarastV3Color.line,
    );
  }
}

class _MoneySettingsMenu extends StatelessWidget {
  const _MoneySettingsMenu({
    required this.canManage,
    required this.onBudget,
    required this.onSchedules,
  });

  final bool canManage;
  final VoidCallback onBudget;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<_MoneySettingsAction>(
        key: const ValueKey('money-settings-menu'),
        tooltip: 'إدارة المال',
        onSelected: (action) {
          switch (action) {
            case _MoneySettingsAction.budget:
              onBudget();
            case _MoneySettingsAction.schedules:
              onSchedules();
          }
        },
        itemBuilder: (context) => [
          if (canManage)
            const PopupMenuItem(
              key: ValueKey('money-settings-budget'),
              value: _MoneySettingsAction.budget,
              child: _MoneySettingsItem(
                icon: LucideIcons.walletCards,
                label: 'الميزانية والتصنيفات',
              ),
            ),
          const PopupMenuItem(
            key: ValueKey('money-settings-schedules'),
            value: _MoneySettingsAction.schedules,
            child: _MoneySettingsItem(
              icon: LucideIcons.calendarClock,
              label: 'مواعيد الدفع',
            ),
          ),
        ],
        child: Container(
          height: 48,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AarastV3Color.paperQuiet,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.slidersHorizontal,
                size: 16,
                color: AarastV3Color.primary,
              ),
              const SizedBox(width: AarastV3Space.x1),
              Text(
                'إدارة',
                style: AarastV3Type.label(
                  context,
                ).copyWith(color: AarastV3Color.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneySettingsItem extends StatelessWidget {
  const _MoneySettingsItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brand),
        const SizedBox(width: AppTheme.space10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({
    required this.schedule,
    required this.currency,
    required this.onTap,
    this.onPay,
  });

  final PaymentSchedule schedule;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final isOverdue = schedule.isOverdueAt(DateTime.now());
    final heading = isOverdue ? 'دفعة متأخرة' : 'موعد الدفع التالي';
    final amountsHidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    final amount = amountsHidden
        ? '••••'
        : formatCompactMoney(
            moneyValue(schedule.amount),
            currencyCode: currency,
          );
    return AarastV3AttentionSurface(
      key: const ValueKey('money-next-schedule-strip'),
      eyebrow: heading,
      title: schedule.costTitle ?? 'تكلفة مسجلة',
      reason: '${formatArabicCompactDate(schedule.dueDate)} · $amount',
      icon: isOverdue ? LucideIcons.alertCircle : LucideIcons.calendarClock,
      actionLabel: onPay == null ? 'عرض التفاصيل' : 'تسجيل دفعة',
      onAction: onPay ?? onTap,
      onTap: onTap,
      tone: isOverdue
          ? AarastV3AttentionTone.danger
          : AarastV3AttentionTone.warning,
    );
  }
}

String _costCountLabel(int count) {
  return switch (count) {
    1 => 'تكلفة واحدة',
    2 => 'تكلفتان',
    >= 3 && <= 10 => '$count تكاليف',
    _ => '$count تكلفة',
  };
}
