import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../models/dashboard_summary.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;

  @override
  State<WeddingPlanDashboardScreen> createState() =>
      _WeddingPlanDashboardScreenState();
}

class _WeddingPlanDashboardScreenState
    extends State<WeddingPlanDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<DashboardSummaryProvider>().loadDashboard(
      widget.weddingPlanId,
      sharedMember: widget.sharedMember,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        bottomNavigationBar: widget.embedded
            ? null
            : DashboardBottomNav(
                activeIndex: 0,
                onHome: () {},
                onMoney: () =>
                    context.push(AppRouter.finance(widget.weddingPlanId)),
                onTasks: () =>
                    context.push(AppRouter.tasks(widget.weddingPlanId)),
                onProviders: () => context.push(AppRouter.providerMarketplace),
                onMore: () => context.push(AppRouter.more),
                onAdd: _showQuickActions,
              ),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppTheme.dMaroon,
            onRefresh: _load,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _buildBody(provider, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DashboardSummaryProvider provider, AuthController auth) {
    final summary = provider.summary;
    final bottomPadding = widget.embedded ? 118.0 : 142.0;

    if (provider.isLoading && summary == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding),
        children: const [_DashboardSkeleton()],
      );
    }

    if (provider.errorMessage != null && summary == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding),
        children: [
          _StateCard(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل الرئيسية',
            message: provider.errorMessage!,
            actionLabel: 'إعادة المحاولة',
            onAction: _load,
          ),
        ],
      );
    }

    if (summary == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding),
        children: [
          _StateCard(
            icon: Icons.event_available_outlined,
            title: 'ابدأ بإنشاء خطتك',
            message: 'لا توجد خطة فعالة بعد. أنشئ خطة زفافك الأولى للمتابعة.',
            actionLabel: 'فتح البداية',
            onAction: () => context.go(AppRouter.onboarding),
          ),
        ],
      );
    }

    return ListView(
      key: ValueKey('dashboard-${summary.planId}'),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        _DashboardHeader(
          name: auth.user?.name ?? 'صاحب الخطة',
          unreadCount: summary.unreadNotificationsCount,
          onNotifications: () =>
              context.push(AppRouter.planNotifications(summary.planId)),
          onMenu: () => context.push(AppRouter.more),
        ),
        const SizedBox(height: 14),
        _GoldenPlanCard(
          summary: summary,
          onOpenPlan: () => context.push(AppRouter.planCenter(summary.planId)),
        ),
        const SizedBox(height: 14),
        _TodaySection(summary: summary, onOpenItem: _openDashboardItem),
        const SizedBox(height: 14),
        _QuickOverview(
          summary: summary,
          onShowAll: () => context.push(AppRouter.planCenter(summary.planId)),
        ),
        const SizedBox(height: 14),
        _ProvidersAndNotificationsSection(
          summary: summary,
          onProviderTap: (providerId) =>
              context.push(AppRouter.providerDetails(providerId)),
          onViewNotifications: () =>
              context.push(AppRouter.planNotifications(summary.planId)),
        ),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 14),
          _InlineNotice(message: provider.errorMessage!),
        ],
      ],
    );
  }

  void _showQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        void open(String route) {
          Navigator.of(sheetContext).pop();
          context.push(route);
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 16),
                  const Text(
                    'إجراءات سريعة!',
                    style: TextStyle(
                      color: AppTheme.dInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'إضافة مصروف',
                    subtitle: 'سجل مصروف جديد',
                    onTap: () =>
                        open(AppRouter.createExpense(widget.weddingPlanId)),
                  ),
                  _QuickActionRow(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'إضافة مهمة',
                    subtitle: 'أنشئ مهمة جديدة',
                    onTap: () =>
                        open(AppRouter.createTask(widget.weddingPlanId)),
                  ),
                  _QuickActionRow(
                    icon: Icons.groups_2_outlined,
                    title: 'إضافة ضيف',
                    subtitle: 'أضف ضيفًا إلى قائمتك',
                    onTap: () =>
                        open(AppRouter.guestList(widget.weddingPlanId)),
                  ),
                  _QuickActionRow(
                    icon: Icons.credit_card_outlined,
                    title: 'إضافة دين',
                    subtitle: 'سجل دينًا أو مبلغًا مستحقًا',
                    onTap: () =>
                        open(AppRouter.createDebt(widget.weddingPlanId)),
                  ),
                  _QuickActionRow(
                    icon: Icons.request_quote_outlined,
                    title: 'طلب عرض سعر',
                    subtitle: 'اطلب تسعيرًا من مزود',
                    onTap: () => open(AppRouter.providerMarketplace),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDashboardItem(DashboardImportantItem item) {
    final route = item.route;
    if (route == null || route.trim().isEmpty) return;
    context.push(route);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.unreadCount,
    required this.onNotifications,
    required this.onMenu,
  });

  final String name;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'الإشعارات',
          onPressed: onNotifications,
          icon: Badge.count(
            count: unreadCount,
            isLabelVisible: unreadCount > 0,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'أعرست',
                style: TextStyle(
                  color: AppTheme.dGoldDeep,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                'مرحبا بك، $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Text(
                'رحلتك نحو يومك الكبير',
                style: TextStyle(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'القائمة',
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded),
        ),
      ],
    );
  }
}

class _GoldenPlanCard extends StatelessWidget {
  const _GoldenPlanCard({required this.summary, required this.onOpenPlan});

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final dateLabel = summary.weddingDate == null
        ? 'لم يحدد الموعد'
        : _formatDate(summary.weddingDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: AppTheme.heroDecoration(),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.dGold2.withValues(alpha: 0.84),
                  size: 30,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'الخطة الذهبية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.dGold2,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 190,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.dCreamBg,
                        foregroundColor: AppTheme.dMaroonDeep,
                        minimumSize: const Size.fromHeight(38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: onOpenPlan,
                      child: const Text(
                        'عرض مركز الخطة',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CountdownPanel(dateLabel: dateLabel, weddingDate: summary.weddingDate),
        const SizedBox(height: 14),
        _ProgressPanel(summary: summary, onOpenPlan: onOpenPlan),
      ],
    );
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.dateLabel, required this.weddingDate});

  final String dateLabel;
  final DateTime? weddingDate;

  @override
  Widget build(BuildContext context) {
    final parts = _CountdownParts.fromDate(weddingDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroon.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'تاريخ الزفاف',
            style: TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CountdownMetric(label: 'يوم', value: parts.days),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountdownMetric(label: 'ساعة', value: parts.hours),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountdownMetric(label: 'دقيقة', value: parts.minutes),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountdownMetric(label: 'ثانية', value: parts.seconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownParts {
  const _CountdownParts({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  factory _CountdownParts.fromDate(DateTime? weddingDate) {
    if (weddingDate == null) {
      return const _CountdownParts(
        days: '--',
        hours: '--',
        minutes: '--',
        seconds: '--',
      );
    }

    final diff = weddingDate.difference(DateTime.now());
    if (diff.isNegative) {
      return const _CountdownParts(
        days: '0',
        hours: '0',
        minutes: '0',
        seconds: '0',
      );
    }

    return _CountdownParts(
      days: diff.inDays.toString(),
      hours: (diff.inHours % 24).toString().padLeft(2, '0'),
      minutes: (diff.inMinutes % 60).toString().padLeft(2, '0'),
      seconds: (diff.inSeconds % 60).toString().padLeft(2, '0'),
    );
  }

  final String days;
  final String hours;
  final String minutes;
  final String seconds;
}

class _CountdownMetric extends StatelessWidget {
  const _CountdownMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.dBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.summary, required this.onOpenPlan});

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: summary.progressPercentage / 100,
                      strokeWidth: 8,
                      backgroundColor: AppTheme.dLine,
                      color: AppTheme.dMaroon,
                    ),
                    Text(
                      '${summary.progressPercentage}%',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppTheme.dMaroonDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تقدم الخطة',
                      style: TextStyle(
                        color: AppTheme.dInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أُنجز ${summary.completedTasks} من ${summary.totalTasks} مهمة',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dMaroon,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onOpenPlan,
              child: const Text(
                'أكمل خطتك ✨',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.summary, required this.onOpenItem});

  final DashboardSummary summary;
  final ValueChanged<DashboardImportantItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final items = summary.importantItems.isNotEmpty
        ? summary.importantItems
        : _fallbackItems();

    return _SectionCard(
      title: 'الأهم اليوم',
      subtitle: 'تساعدك على التركيز على ما يهم الآن',
      child: items.isEmpty
          ? summary.totalTasks == 0
                ? _FirstTaskEmptyState(
                    onAddTask: () => onOpenItem(
                      DashboardImportantItem(
                        id: 'first-task',
                        type: 'TASK_TODAY',
                        title: 'ابدأ بإضافة أول مهمة',
                        subtitle: 'خطتك تستحق بداية منظمة',
                        body: null,
                        icon: 'calendar',
                        tone: 'info',
                        actionLabel: 'إضافة مهمة الآن',
                        route: AppRouter.createTask(summary.planId),
                        data: const {},
                      ),
                    ),
                  )
                : const _SmallEmpty(
                    icon: Icons.task_alt_rounded,
                    title: 'لا توجد عناصر عاجلة',
                    message: 'سنظهر هنا المهام أو الأقساط القريبة عند توفرها.',
                  )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ImportantItemCard(
                    item: items[i],
                    onTap: () => onOpenItem(items[i]),
                  ),
                ],
              ],
            ),
    );
  }

  List<DashboardImportantItem> _fallbackItems() {
    return [
      if (summary.overdueTasks > 0)
        DashboardImportantItem(
          id: 'overdue-tasks',
          type: 'TASK_OVERDUE',
          title: 'مهام متأخرة',
          subtitle: '${summary.overdueTasks} مهمة تحتاج متابعة',
          body: 'افتح المهام وحدد أول خطوة الآن.',
          icon: 'calendar',
          tone: 'danger',
          actionLabel: 'تنفيذ الآن',
          route: AppRouter.tasks(summary.planId),
          data: const {},
        ),
      if (summary.todayTasks > 0)
        DashboardImportantItem(
          id: 'today-tasks',
          type: 'TASK_TODAY',
          title: 'مهام اليوم',
          subtitle: '${summary.todayTasks} مهمة على جدول اليوم',
          body: 'راجع مهام اليوم حتى تبقى الخطة مرتبة.',
          icon: 'calendar',
          tone: 'info',
          actionLabel: 'فتح المهام',
          route: AppRouter.tasks(summary.planId),
          data: const {},
        ),
      if ((summary.dueInstallmentsCount ?? 0) > 0)
        DashboardImportantItem(
          id: 'due-installments',
          type: 'INSTALLMENT_DUE',
          title: 'دفعة قادمة',
          subtitle: '${summary.dueInstallmentsCount} قسط يحتاج مراجعة',
          body: 'البيانات المالية تظهر حسب صلاحياتك فقط.',
          icon: 'wallet',
          tone: 'warning',
          actionLabel: 'عرض التفاصيل',
          route: AppRouter.debts(summary.planId),
          data: const {},
        ),
    ];
  }
}

class _QuickOverview extends StatelessWidget {
  const _QuickOverview({required this.summary, required this.onShowAll});

  final DashboardSummary summary;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final budgetUsage = _budgetUsage(summary);

    return _SectionCard(
      title: 'نظرة سريعة',
      subtitle: 'ملخص سريع لحالتك اليوم',
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.04,
            children: [
              _OverviewTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'المال',
                value: summary.canViewMoney
                    ? _money(summary.spentTotal ?? summary.budgetTotal)
                    : 'خاص',
                helper: summary.canViewMoney
                    ? '${budgetUsage ?? 0}% من الميزانية'
                    : 'حسب الصلاحية',
                progress: budgetUsage == null ? null : budgetUsage / 100,
              ),
              _OverviewTile(
                icon: Icons.fact_check_outlined,
                label: 'المهام',
                value: '${summary.completedTasks} من ${summary.totalTasks}',
                helper: 'مكتملة',
                progress: summary.totalTasks == 0
                    ? null
                    : summary.completedTasks / summary.totalTasks,
              ),
              _OverviewTile(
                icon: Icons.storefront_outlined,
                label: 'الموردون',
                value: '${summary.providerCount}',
                helper: 'تم الحجز',
              ),
              _OverviewTile(
                icon: Icons.groups_2_outlined,
                label: 'الضيوف',
                value: '${summary.guestCount}',
                helper: '${summary.confirmedGuests} تأكيد',
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dMaroon,
              side: const BorderSide(color: AppTheme.dLine),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onShowAll,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text(
              'عرض كل التفاصيل',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ImportantItemCard extends StatelessWidget {
  const _ImportantItemCard({required this.item, required this.onTap});

  final DashboardImportantItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(item.tone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroon.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForImportant(item.icon), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.body != null && item.body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.body!,
                    style: const TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dMaroon,
                      side: const BorderSide(color: AppTheme.dLine),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onTap,
                    child: Text(
                      item.actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
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

class _FirstTaskEmptyState extends StatelessWidget {
  const _FirstTaskEmptyState({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.dBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppTheme.dCreamBg,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppTheme.dGoldDeep,
              size: 46,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'ابدأ بإضافة أول مهمة',
            style: TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أضف مهامك خطوة بخطوة وسنرتب لك المسار الصحيح.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dMaroon,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onAddTask,
              child: const Text(
                'إضافة مهمة الآن ✨',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SyncPill(generatedAt: null),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.dGoldDeep, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress!.clamp(0, 1),
                backgroundColor: AppTheme.dLine,
                color: AppTheme.dGoldDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProvidersAndNotificationsSection extends StatelessWidget {
  const _ProvidersAndNotificationsSection({
    required this.summary,
    required this.onProviderTap,
    required this.onViewNotifications,
  });

  final DashboardSummary summary;
  final ValueChanged<String> onProviderTap;
  final VoidCallback onViewNotifications;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          title: 'مزودو الخطة',
          subtitle: 'الموردون المرتبطون بخطتك',
          child: summary.planProviders.isEmpty
              ? const _SmallEmpty(
                  icon: Icons.storefront_outlined,
                  title: 'لا يوجد مزودون مرتبطون بعد',
                  message: 'عند طلب عرض سعر أو حفظ مزود للخطة سيظهر هنا بوضوح.',
                )
              : SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: summary.planProviders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final provider = summary.planProviders[index];
                      return _ProviderPreviewCard(
                        provider: provider,
                        onTap: () => onProviderTap(provider.providerId),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'الإشعارات المهمة',
          subtitle: 'آخر التنبيهات المرتبطة بهذه الخطة',
          child: summary.importantNotifications.isEmpty
              ? const _SmallEmpty(
                  icon: Icons.notifications_none_rounded,
                  title: 'لا توجد إشعارات مهمة',
                  message: 'سنظهر هنا التنبيهات القابلة للتنفيذ فقط.',
                )
              : Column(
                  children: [
                    for (
                      var i = 0;
                      i < summary.importantNotifications.length;
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _NotificationPreviewTile(
                        notification: summary.importantNotifications[i],
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dMaroon,
                        side: const BorderSide(color: AppTheme.dLine),
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onViewNotifications,
                      child: const Text(
                        'عرض كل الإشعارات',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SyncPill(generatedAt: summary.generatedAt),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProviderPreviewCard extends StatelessWidget {
  const _ProviderPreviewCard({required this.provider, required this.onTap});

  final DashboardProviderPreview provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service =
        provider.serviceTitle ?? provider.categoryName ?? 'مزود خدمة';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ProviderImage(url: provider.imageUrl),
                    ),
                  ),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: AppTheme.dMaroon,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              provider.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            Text(
              service,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 14,
                ),
                const SizedBox(width: 3),
                Text(
                  provider.ratingAverage,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderImage extends StatelessWidget {
  const _ProviderImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        color: AppTheme.dCreamBg,
        child: const Icon(
          Icons.storefront_outlined,
          color: AppTheme.dGoldDeep,
          size: 34,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.dCreamBg,
        child: const Icon(
          Icons.storefront_outlined,
          color: AppTheme.dGoldDeep,
          size: 34,
        ),
      ),
    );
  }
}

class _NotificationPreviewTile extends StatelessWidget {
  const _NotificationPreviewTile({required this.notification});

  final DashboardNotificationPreview notification;

  @override
  Widget build(BuildContext context) {
    final color = notification.readAt == null
        ? AppTheme.dMaroon
        : AppTheme.dMuted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(_notificationIcon(notification.type), color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(notification.createdAt),
            style: const TextStyle(
              color: AppTheme.dMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.generatedAt});

  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.dGreenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_done_outlined,
            color: AppTheme.dGreen,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            generatedAt == null
                ? 'آخر مزامنة محفوظة'
                : 'آخر مزامنة ${_timeAgo(generatedAt!)}',
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusLg),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.dGoldDeep, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _SmallEmpty extends StatelessWidget {
  const _SmallEmpty({
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
        Icon(icon, color: AppTheme.dGoldDeep, size: 40),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.dInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCreamBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.dInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonBox(height: 74),
        SizedBox(height: 14),
        _SkeletonBox(height: 244),
        SizedBox(height: 14),
        _SkeletonBox(height: 164),
        SizedBox(height: 14),
        _SkeletonBox(height: 220),
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
        color: AppTheme.dCard2.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.dPinkBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.dMaroon, size: 21),
      ),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppTheme.dInkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.chevron_left_rounded),
    );
  }
}

Color _toneColor(String tone) {
  switch (tone) {
    case 'danger':
      return AppTheme.danger;
    case 'warning':
      return AppTheme.dOrange;
    case 'success':
      return AppTheme.dGreen;
    default:
      return AppTheme.dBlue;
  }
}

IconData _iconForImportant(String icon) {
  switch (icon) {
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    case 'provider':
      return Icons.photo_camera_outlined;
    case 'calendar':
    default:
      return Icons.event_note_rounded;
  }
}

IconData _notificationIcon(String type) {
  if (type.contains('TASK')) return Icons.notifications_none_rounded;
  if (type.contains('INSTALLMENT')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (type.contains('QUOTE')) return Icons.request_quote_outlined;
  if (type.contains('SHARING')) return Icons.group_add_outlined;
  return Icons.notifications_none_rounded;
}

int? _budgetUsage(DashboardSummary summary) {
  final spent = double.tryParse(summary.spentTotal ?? '');
  final total = double.tryParse(summary.budgetTotal ?? '');
  if (spent == null || total == null || total <= 0) return null;
  return ((spent / total) * 100).round().clamp(0, 999);
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return _formatDate(date);
}

String _formatDate(DateTime date) {
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _money(String? value) {
  if (value == null || value.trim().isEmpty) return 'غير محدد';
  final parsed = double.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.round()} ريال';
}
