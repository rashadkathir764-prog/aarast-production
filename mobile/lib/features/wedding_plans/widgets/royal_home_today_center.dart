import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dashboard_summary.dart';

class RoyalHomeTodayCenter extends StatelessWidget {
  const RoyalHomeTodayCenter({
    required this.summary,
    required this.userName,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenNotifications,
    required this.onOpenImportantItem,
    required this.onOpenNextStep,
    this.bottomPadding = 156,
    this.notice,
    super.key,
  });

  final DashboardSummary summary;
  final String userName;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenNotifications;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;
  final VoidCallback onOpenNextStep;
  final double bottomPadding;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final priorities = _priorityItems(summary);
    final nextStep = priorities.isEmpty ? null : priorities.first;

    return DecoratedBox(
      decoration: const BoxDecoration(color: _RoyalColors.ivory),
      child: ListView(
        key: ValueKey('royal-home-${summary.planId}'),
        padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
        children: [
          _Entrance(
            delay: Duration.zero,
            child: _RoyalHeader(
              userName: userName,
              unreadCount: summary.unreadNotificationsCount,
              onNotifications: onNotifications,
              onProfile: onProfile,
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            _Entrance(delay: const Duration(milliseconds: 25), child: notice!),
          ],
          const SizedBox(height: 16),
          _Entrance(
            delay: const Duration(milliseconds: 50),
            child: _HeroPlanCard(summary: summary, onOpenPlan: onOpenPlan),
          ),
          const SizedBox(height: 22),
          _Entrance(
            delay: const Duration(milliseconds: 100),
            child: _PrioritySection(
              priorities: priorities.take(3).toList(),
              onOpenImportantItem: onOpenImportantItem,
            ),
          ),
          const SizedBox(height: 12),
          _Entrance(
            delay: const Duration(milliseconds: 150),
            child: _NextStepCard(
              item: nextStep,
              onOpenNextStep: onOpenNextStep,
            ),
          ),
          const SizedBox(height: 24),
          _Entrance(
            delay: const Duration(milliseconds: 200),
            child: _MoneySummaryCard(
              summary: summary,
              onOpenMoney: onOpenMoney,
            ),
          ),
          const SizedBox(height: 20),
          _Entrance(
            delay: const Duration(milliseconds: 250),
            child: _CompactCardsGrid(
              summary: summary,
              onOpenTasks: onOpenTasks,
              onOpenProviders: onOpenProviders,
              onOpenGuests: onOpenGuests,
              onOpenNotifications: onOpenNotifications,
            ),
          ),
        ],
      ),
    );
  }
}

class RoyalHomeTodaySkeleton extends StatelessWidget {
  const RoyalHomeTodaySkeleton({this.bottomPadding = 156, super.key});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
      children: const [
        _SkeletonBox(height: 56),
        SizedBox(height: 16),
        _SkeletonBox(height: 188),
        SizedBox(height: 22),
        _SkeletonBox(height: 248),
        SizedBox(height: 18),
        _SkeletonBox(height: 156),
        SizedBox(height: 20),
        _SkeletonBox(height: 220),
      ],
    );
  }
}

class _RoyalHeader extends StatelessWidget {
  const _RoyalHeader({
    required this.userName,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
  });

  final String userName;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أعرست ✨',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _RoyalColors.burgundy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _greetingFor(userName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RoyalColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          showBadge: unreadCount > 0,
        ),
        const SizedBox(width: 10),
        _CircleIconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
      ],
    );
  }
}

class _HeroPlanCard extends StatelessWidget {
  const _HeroPlanCard({required this.summary, required this.onOpenPlan});

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onOpenPlan,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_RoyalColors.burgundy, _RoyalColors.burgundyDark],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _RoyalColors.burgundy.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.15,
                      colors: [
                        _RoyalColors.gold.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroRow(
                            label: 'الخطة:',
                            value: summary.title,
                            valueColor: _RoyalColors.gold,
                            valueSize: 17,
                          ),
                          _HeroRow(
                            label: 'الموقع:',
                            value: _nonEmpty(summary.city, 'غير محدد'),
                          ),
                          _HeroRow(
                            label: 'تاريخ الزواج:',
                            value: summary.weddingDate == null
                                ? 'غير محدد'
                                : _formatDate(summary.weddingDate!),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _daysRemainingLabel(summary.daysRemaining),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _RoyalColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _ProgressColumn(percent: summary.progressPercentage),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _HeroStatus(status: summary.status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Flexible(
                              child: Text(
                                'متابعة الخطة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({
    required this.priorities,
    required this.onOpenImportantItem,
  });

  final List<DashboardImportantItem> priorities;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الأهم اليوم',
          style: TextStyle(
            color: _RoyalColors.burgundy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < priorities.length; i++) ...[
          _PriorityCard(
            item: priorities[i],
            onTap: () => onOpenImportantItem(priorities[i]),
          ),
          if (i != priorities.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.item, required this.onTap});

  final DashboardImportantItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.tone);

    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(radius: 18),
        child: Row(
          children: [
            _ToneIcon(icon: _iconFor(item.icon, item.type), tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ToneBadge(label: item.subtitle, tone: tone),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RoyalColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_left_rounded,
              color: _RoyalColors.muted.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.item, required this.onOpenNextStep});

  final DashboardImportantItem? item;
  final VoidCallback onOpenNextStep;

  @override
  Widget build(BuildContext context) {
    final selected = item;
    final actionLabel = _nonEmpty(selected?.actionLabel, 'متابعة');
    final message = selected == null
        ? 'راجع خطتك وحدد الخطوة التي تحتاج انتباهك اليوم.'
        : _nextStepText(selected);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _RoyalColors.gold.withValues(alpha: 0.11),
            _RoyalColors.gold.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _RoyalColors.gold.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: _RoyalColors.gold.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: _RoyalColors.burgundy,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الخطوة التالية المقترحة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _RoyalColors.burgundy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RoyalColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Pressable(
            onTap: onOpenNextStep,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 40,
              constraints: const BoxConstraints(minWidth: 108),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _RoyalColors.burgundy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({required this.summary, required this.onOpenMoney});

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;

  @override
  Widget build(BuildContext context) {
    if (!summary.canViewMoney) {
      return _SummaryCard(
        title: 'المال',
        actionLabel: 'عرض المال',
        onAction: onOpenMoney,
        child: const _LockedMoneyState(),
      );
    }

    final upcoming = _upcomingInstallmentLabel(summary);

    return _SummaryCard(
      title: 'المال',
      actionLabel: 'عرض المال',
      onAction: onOpenMoney,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: 'الميزانية',
                  value: _money(summary.budgetTotal),
                  color: _RoyalColors.burgundy,
                  large: true,
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'المتبقي',
                  value: _money(summary.remainingBudget),
                  color: _RoyalColors.gold,
                  large: true,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const _SoftDivider(),
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: 'المصروف',
                  value: _money(summary.spentTotal),
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'الديون',
                  value: _money(summary.unpaidDebtTotal ?? summary.debtTotal),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const _SoftDivider(),
          Row(
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallDot(color: _RoyalColors.warning),
                  SizedBox(width: 7),
                  Text(
                    'قسط قادم',
                    style: TextStyle(
                      color: _RoyalColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  upcoming,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: _RoyalColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactCardsGrid extends StatelessWidget {
  const _CompactCardsGrid({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenNotifications,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final upcomingTasks =
        summary.totalTasks -
        summary.completedTasks -
        summary.todayTasks -
        summary.overdueTasks;
    final missingGuests = math.max(
      0,
      summary.guestCount - summary.confirmedGuests,
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CompactStatsCard(
                title: 'المهام',
                actionLabel: 'عرض',
                onAction: onOpenTasks,
                stats: [
                  _CompactStat('اليوم', summary.todayTasks.toString()),
                  _CompactStat(
                    'متأخرة',
                    summary.overdueTasks.toString(),
                    color: _RoyalColors.danger,
                  ),
                  _CompactStat('قادمة', math.max(0, upcomingTasks).toString()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompactStatsCard(
                title: 'الموردون',
                actionLabel: 'مراجعة',
                onAction: onOpenProviders,
                stats: [
                  _CompactStat(
                    'عروض',
                    summary.planProviders.length.toString(),
                    color: _RoyalColors.success,
                  ),
                  _CompactStat(
                    'مفتوحة',
                    summary.quoteRequestsCount.toString(),
                    color: _RoyalColors.warning,
                  ),
                  _CompactStat('متفق', summary.providerCount.toString()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CompactStatsCard(
                title: 'الضيوف',
                actionLabel: 'إدارة',
                onAction: onOpenGuests,
                stats: [
                  _CompactStat('الإجمالي', summary.guestCount.toString()),
                  _CompactStat(
                    'مؤكد',
                    summary.confirmedGuests.toString(),
                    color: _RoyalColors.success,
                  ),
                  _CompactStat(
                    'ناقص',
                    missingGuests.toString(),
                    color: _RoyalColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NotificationsCompactCard(
                summary: summary,
                onAction: onOpenNotifications,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CompactStatsCard extends StatelessWidget {
  const _CompactStatsCard({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.stats,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final List<_CompactStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 134),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
            compact: true,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final stat in stats)
                Expanded(child: _CompactStatView(stat: stat)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsCompactCard extends StatelessWidget {
  const _NotificationsCompactCard({
    required this.summary,
    required this.onAction,
  });

  final DashboardSummary summary;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final notifications = summary.importantNotifications.take(2).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 134),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'إشعارات',
            actionLabel: 'الكل',
            onAction: onAction,
            compact: true,
          ),
          const SizedBox(height: 18),
          if (notifications.isEmpty)
            Text(
              summary.unreadNotificationsCount > 0
                  ? '${summary.unreadNotificationsCount} تنبيه غير مقروء'
                  : 'لا توجد تنبيهات مهمة',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _RoyalColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            )
          else
            for (var i = 0; i < notifications.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _NotificationLine(notification: notifications[i]),
            ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.compact = false,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _RoyalColors.burgundy,
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        _Pressable(
          onTap: onAction,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _RoyalColors.gold,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_left_rounded,
                color: _RoyalColors.gold,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({
    required this.label,
    required this.value,
    this.color = _RoyalColors.ink,
    this.large = false,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool large;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _RoyalColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textDirection: TextDirection.ltr,
          textAlign: alignEnd ? TextAlign.left : TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: large ? 21 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CompactStatView extends StatelessWidget {
  const _CompactStatView({required this.stat});

  final _CompactStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: stat.color ?? _RoyalColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _RoyalColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _NotificationLine extends StatelessWidget {
  const _NotificationLine({required this.notification});

  final DashboardNotificationPreview notification;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SmallDot(
          color: notification.readAt == null
              ? _RoyalColors.success
              : _RoyalColors.warning,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            notification.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _RoyalColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressColumn extends StatelessWidget {
  const _ProgressColumn({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return Column(
      children: [
        const Text(
          'التقدم',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped / 100),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return CustomPaint(
                    painter: _ProgressRingPainter(value: value),
                    size: const Size.square(68),
                  );
                },
              ),
              Text(
                '$clamped%',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: _RoyalColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 7;
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = _RoyalColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      value.clamp(0, 1) * math.pi * 2,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.valueSize = 14,
  });

  final String label;
  final String value;
  final Color valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: valueSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'الحالة: ${_statusLabel(status)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ToneIcon extends StatelessWidget {
  const _ToneIcon({required this.icon, required this.tone});

  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: tone.color, size: 23),
    );
  }
}

class _ToneBadge extends StatelessWidget {
  const _ToneBadge({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _nonEmpty(label, tone.defaultLabel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tone.color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
              boxShadow: [
                BoxShadow(
                  color: _RoyalColors.burgundy.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: _RoyalColors.burgundy, size: 23),
          ),
          if (showBadge)
            PositionedDirectional(
              top: 12,
              end: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _RoyalColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final start = delay.inMilliseconds / (500 + delay.inMilliseconds);
        final normalized = delay == Duration.zero
            ? value
            : ((value - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: normalized,
          child: Transform.translate(
            offset: Offset(0, (1 - normalized) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _LockedMoneyState extends StatelessWidget {
  const _LockedMoneyState();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: _RoyalColors.muted),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'غير متاح حسب صلاحياتك',
            style: TextStyle(
              color: _RoyalColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _RoyalColors.line),
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _RoyalColors.burgundy.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  const _SmallDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CompactStat {
  const _CompactStat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;
}

class _Tone {
  const _Tone({required this.color, required this.defaultLabel});

  final Color color;
  final String defaultLabel;
}

BoxDecoration _cardDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
    boxShadow: [
      BoxShadow(
        color: _RoyalColors.burgundy.withValues(alpha: 0.04),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

List<DashboardImportantItem> _priorityItems(DashboardSummary summary) {
  final items = [...summary.importantItems];

  // TODO(home-dashboard): Replace fallback suggestions with backend-ranked
  // importantItems once the aggregate reliably returns three Today Center cards.
  void addFallback({
    required String id,
    required String type,
    required String title,
    required String subtitle,
    required String icon,
    required String tone,
    required String actionLabel,
  }) {
    if (items.length >= 3 || items.any((item) => item.type == type)) return;
    items.add(
      DashboardImportantItem(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        icon: icon,
        tone: tone,
        actionLabel: actionLabel,
        data: const {},
      ),
    );
  }

  if ((summary.dueInstallmentsCount ?? 0) > 0) {
    addFallback(
      id: 'fallback-installments',
      type: 'INSTALLMENT_DUE',
      title: 'لديك ${summary.dueInstallmentsCount} قسط قريب',
      subtitle: 'مستحق قريباً',
      icon: 'wallet',
      tone: 'warning',
      actionLabel: 'عرض المال',
    );
  }
  if (summary.quoteRequestsCount > 0 || summary.planProviders.isNotEmpty) {
    addFallback(
      id: 'fallback-quotes',
      type: 'QUOTE_RECEIVED',
      title: 'راجع عروض الموردين المفتوحة',
      subtitle: 'عرض جديد',
      icon: 'provider',
      tone: 'success',
      actionLabel: 'مراجعة العرض',
    );
  }
  if (summary.overdueTasks > 0) {
    addFallback(
      id: 'fallback-overdue-task',
      type: 'TASK_OVERDUE',
      title: 'لديك ${summary.overdueTasks} مهمة متأخرة',
      subtitle: 'متأخر',
      icon: 'calendar',
      tone: 'danger',
      actionLabel: 'فتح المهام',
    );
  }
  if (summary.todayTasks > 0) {
    addFallback(
      id: 'fallback-today-task',
      type: 'TASK_TODAY',
      title: 'مهمة اليوم بحاجة متابعة',
      subtitle: 'اليوم',
      icon: 'calendar',
      tone: 'warning',
      actionLabel: 'فتح المهام',
    );
  }

  addFallback(
    id: 'fallback-plan',
    type: 'PLAN_REVIEW',
    title: 'راجع مركز الخطة وتأكد من التفاصيل',
    subtitle: 'متابعة',
    icon: 'calendar',
    tone: 'success',
    actionLabel: 'متابعة الخطة',
  );
  addFallback(
    id: 'fallback-budget',
    type: 'BUDGET_REVIEW',
    title: 'تأكد أن المصروفات تناسب الميزانية',
    subtitle: 'مراجعة مالية',
    icon: 'wallet',
    tone: 'warning',
    actionLabel: 'عرض المال',
  );
  addFallback(
    id: 'fallback-guests',
    type: 'GUEST_REVIEW',
    title: 'حدّث قائمة الضيوف قبل إرسال الدعوات',
    subtitle: 'اقتراح',
    icon: 'guests',
    tone: 'info',
    actionLabel: 'إدارة الضيوف',
  );

  return items.take(3).toList();
}

_Tone _toneFor(String tone) {
  switch (tone) {
    case 'danger':
      return const _Tone(color: _RoyalColors.danger, defaultLabel: 'متأخر');
    case 'success':
      return const _Tone(color: _RoyalColors.success, defaultLabel: 'جديد');
    case 'warning':
      return const _Tone(
        color: _RoyalColors.warning,
        defaultLabel: 'مستحق قريباً',
      );
    default:
      return const _Tone(color: _RoyalColors.info, defaultLabel: 'مهم');
  }
}

IconData _iconFor(String icon, String type) {
  if (type.contains('QUOTE') || icon == 'provider') {
    return Icons.request_quote_outlined;
  }
  if (type.contains('INSTALLMENT') || icon == 'wallet') {
    return Icons.credit_card_outlined;
  }
  if (icon == 'guests') return Icons.groups_2_outlined;
  return Icons.info_outline_rounded;
}

String _greetingFor(String userName) {
  final trimmed = userName.trim();
  if (trimmed.isEmpty || trimmed == 'صاحب الخطة') {
    return 'مساء الخير، جاهزة نكمل خطتك؟';
  }
  return 'مساء الخير يا $trimmed، جاهزة نكمل خطتك؟';
}

String _nonEmpty(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

String _daysRemainingLabel(int? days) {
  if (days == null) return 'باقي غير محدد';
  if (days <= 0) return 'اليوم هو موعد الخطة';
  return 'باقي $days يوم';
}

String _statusLabel(String status) {
  switch (status) {
    case 'COMPLETED':
      return 'مكتملة';
    case 'ARCHIVED':
      return 'مؤرشفة';
    case 'PLANNING':
    default:
      return 'قيد التجهيز';
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
  return '${date.day} ${months[date.month - 1]}';
}

String _money(String? value) {
  final parsed = double.tryParse(value?.replaceAll(',', '').trim() ?? '');
  if (parsed == null) return 'غير محدد';
  final rounded = parsed.round();
  final formatted = _formatNumber(rounded);
  // TODO(home-dashboard): Add currency to the dashboard summary contract.
  return '$formatted YER';
}

String _formatNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

String _upcomingInstallmentLabel(DashboardSummary summary) {
  final item = summary.importantItems.firstWhereOrNull(
    (item) => item.type.contains('INSTALLMENT') && item.amount != null,
  );
  if (item?.amount != null) return _money(item!.amount);
  final count = summary.dueInstallmentsCount ?? 0;
  return count > 0 ? '$count أقساط قريبة' : 'لا توجد أقساط قريبة';
}

String _nextStepText(DashboardImportantItem item) {
  final body = item.body?.trim();
  if (body != null && body.isNotEmpty) return body;
  return item.title;
}

class _RoyalColors {
  const _RoyalColors._();

  static const ivory = Color(0xFFFDFBF9);
  static const burgundy = Color(0xFF800020);
  static const burgundyDark = Color(0xFF5A0015);
  static const gold = Color(0xFFD4AF37);
  static const ink = Color(0xFF2D1A1E);
  static const muted = Color(0xFF8A7B7E);
  static const line = Color(0xFFF0E6DE);
  static const danger = Color(0xFFBA2D3F);
  static const warning = Color(0xFFD98A2C);
  static const success = Color(0xFF3D8252);
  static const info = Color(0xFF3F6FB0);
}

extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
