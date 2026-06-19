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
                activeIndex: 4,
                onHome: () {},
                onTasks: _showDeferredPhase,
                onPlans: _showDeferredPhase,
                onMore: () => context.go(AppRouter.home),
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
          onMenu: _showQuickActions,
        ),
        const SizedBox(height: 14),
        _GoldenPlanCard(summary: summary),
        const SizedBox(height: 14),
        _TodaySection(summary: summary),
        const SizedBox(height: 14),
        _QuickOverview(summary: summary),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 14),
          _InlineNotice(message: provider.errorMessage!),
        ],
      ],
    );
  }

  void _showDeferredPhase() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('سيكتمل هذا المسار في المراحل القادمة.')),
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _SheetHandle(),
                  SizedBox(height: 16),
                  Text(
                    'إجراءات سريعة',
                    style: TextStyle(
                      color: AppTheme.dInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 10),
                  _DeferredActionRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'إضافة مصروف',
                  ),
                  _DeferredActionRow(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'إضافة مهمة',
                  ),
                  _DeferredActionRow(
                    icon: Icons.groups_2_outlined,
                    title: 'إضافة ضيف',
                  ),
                  _DeferredActionRow(
                    icon: Icons.storefront_outlined,
                    title: 'طلب عرض سعر',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
  const _GoldenPlanCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final dateLabel = summary.weddingDate == null
        ? 'لم يحدد الموعد'
        : _formatDate(summary.weddingDate!);
    final daysLabel = summary.daysRemaining == null
        ? 'غير محدد'
        : summary.daysRemaining! < 0
        ? 'انتهى الموعد'
        : '${summary.daysRemaining} يوم';

    return Container(
      decoration: AppTheme.heroDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.dGold2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'الخطة الذهبية',
                      style: TextStyle(
                        color: AppTheme.dGold2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      summary.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CountdownPanel(dateLabel: dateLabel, daysLabel: daysLabel),
          const SizedBox(height: 14),
          _ProgressPanel(summary: summary),
        ],
      ),
    );
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.dateLabel, required this.daysLabel});

  final String dateLabel;
  final String daysLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeroMetric(label: 'تاريخ الزفاف', value: dateLabel),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _HeroMetric(label: 'العد التنازلي', value: daysLabel),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
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
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <_TodayItem>[
      if (summary.overdueTasks > 0)
        _TodayItem(
          icon: Icons.warning_amber_rounded,
          title: 'مهام متأخرة',
          subtitle: '${summary.overdueTasks} مهمة تحتاج متابعة',
          color: AppTheme.danger,
        ),
      if (summary.todayTasks > 0)
        _TodayItem(
          icon: Icons.today_rounded,
          title: 'مهام اليوم',
          subtitle: '${summary.todayTasks} مهمة على جدول اليوم',
          color: AppTheme.dBlue,
        ),
      if ((summary.dueInstallmentsCount ?? 0) > 0)
        _TodayItem(
          icon: Icons.payments_outlined,
          title: 'أقساط مستحقة',
          subtitle: '${summary.dueInstallmentsCount} قسط يحتاج مراجعة',
          color: AppTheme.dGoldDeep,
        ),
    ];

    return _SectionCard(
      title: 'الأهم اليوم',
      subtitle: 'ما يحتاج تركيزك الآن',
      child: items.isEmpty
          ? const _SmallEmpty(
              icon: Icons.task_alt_rounded,
              title: 'لا توجد عناصر عاجلة',
              message: 'سنظهر هنا المهام أو الأقساط القريبة عند توفرها.',
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TodayRow(item: items[i]),
                ],
              ],
            ),
    );
  }
}

class _QuickOverview extends StatelessWidget {
  const _QuickOverview({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'نظرة سريعة',
      subtitle: 'ملخص سريع لحالتك اليوم',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.12,
        children: [
          _OverviewTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'المال',
            value: summary.canViewMoney
                ? _money(summary.spentTotal ?? summary.budgetTotal)
                : 'خاص',
            helper: summary.canViewMoney ? 'المصاريف الكلية' : 'حسب الصلاحية',
          ),
          _OverviewTile(
            icon: Icons.fact_check_outlined,
            label: 'المهام',
            value: '${summary.completedTasks} من ${summary.totalTasks}',
            helper: 'مكتملة',
          ),
          _OverviewTile(
            icon: Icons.storefront_outlined,
            label: 'الموردون',
            value: '${summary.providerCount}',
            helper: 'مرتبط بالخطة',
          ),
          _OverviewTile(
            icon: Icons.groups_2_outlined,
            label: 'الضيوف',
            value: '${summary.guestCount}',
            helper: '${summary.confirmedGuests} مؤكد',
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

class _TodayItem {
  const _TodayItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.item});

  final _TodayItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.subtitle,
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
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;

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
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
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

class _DeferredActionRow extends StatelessWidget {
  const _DeferredActionRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title, textAlign: TextAlign.right),
      subtitle: const Text('سيكتمل في مرحلة لاحقة', textAlign: TextAlign.right),
    );
  }
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
