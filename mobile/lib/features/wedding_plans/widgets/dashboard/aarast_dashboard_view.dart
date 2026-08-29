import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3.dart';
import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatters.dart' show compactMoneyParts;
import '../../../../core/widgets/aarast_pressable.dart';
import '../../../../core/widgets/aarast_header_actions.dart';
import '../../../../core/widgets/aarast_surface.dart';
import '../../../wedding_day/wedding_day_api.dart'
    show WeddingDayModeStatus, WeddingDayPhase, resolveWeddingDayMode;
import '../../models/dashboard_summary.dart';
import '../../models/wedding_plan_stage.dart';
import 'aarast_dashboard_focus.dart';

part 'aarast_dashboard_sections.dart';
part 'aarast_dashboard_mosaic.dart';
part 'aarast_dashboard_money_card.dart';
part 'aarast_dashboard_states.dart';
part 'aarast_dashboard_support.dart';

class AarastDashboardView extends StatelessWidget {
  const AarastDashboardView({
    required this.summary,
    required this.userName,
    this.avatarUrl,
    required this.bottomPadding,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenSharing,
    required this.onOpenWeddingDay,
    required this.onOpenNextStep,
    required this.onOpenImportantItem,
    this.personaHeadline,
    this.notice,
    this.now,
    super.key,
  });

  final DashboardSummary summary;
  final String userName;
  final String? avatarUrl;
  final double bottomPadding;
  final String? personaHeadline;
  final Widget? notice;
  final DateTime? now;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenSharing;
  final VoidCallback onOpenWeddingDay;
  final VoidCallback onOpenNextStep;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  bool get _hasBudget => dashboardAmount(summary.totalBudgetForDisplay) != null;
  bool get _isStarting =>
      !_hasBudget || summary.totalTasks == 0 || summary.guestCount == 0;

  @override
  Widget build(BuildContext context) {
    final focus = resolveDashboardFocus(summary);
    final weddingDay = resolveWeddingDayMode(summary.weddingDate, now: now);
    final planStage = resolveWeddingPlanStage(summary.weddingDate, now: now);

    return ColoredBox(
      color: AppTheme.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return ListView(
            key: ValueKey('aarast-home-${summary.planId}'),
            padding: EdgeInsets.fromLTRB(
              wide ? AppTheme.space32 : AppTheme.space16,
              wide ? AppTheme.space20 : AppTheme.space12,
              wide ? AppTheme.space32 : AppTheme.space16,
              bottomPadding,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardHeader(
                        userName: userName,
                        avatarUrl: avatarUrl,
                        summary: summary,
                        onNotifications: onNotifications,
                        onProfile: onProfile,
                        now: now,
                      ),
                      if (notice != null) ...[
                        const SizedBox(height: AppTheme.space16),
                        notice!,
                      ],
                      SizedBox(
                        height: wide ? AppTheme.space20 : AppTheme.space12,
                      ),
                      _PlanMoment(
                        summary: summary,
                        stage: planStage,
                        personaHeadline: personaHeadline,
                        onTap: onOpenPlan,
                      ),
                      if (weddingDay.isVisible) ...[
                        const SizedBox(height: AppTheme.space10),
                        _WeddingDayEntry(
                          status: weddingDay,
                          onTap: onOpenWeddingDay,
                        ),
                      ],
                      if (wide) ...[
                        const SizedBox(height: AppTheme.space10),
                        AarastMotionSwitcher(
                          alignment: AlignmentDirectional.centerStart,
                          child: _FocusPanel(
                            key: ValueKey(
                              'focus-${focus.target.name}-${focus.title}',
                            ),
                            focus: focus,
                            onTap: () => _openFocus(focus),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  _PlanPulse(
                                    summary: summary,
                                    onOpenTasks: onOpenTasks,
                                    onOpenGuests: onOpenGuests,
                                    onOpenProviders: onOpenProviders,
                                  ),
                                  if (summary.canViewMoney) ...[
                                    const SizedBox(height: AppTheme.space24),
                                    _MoneySection(
                                      summary: summary,
                                      onOpenMoney: onOpenMoney,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppTheme.space24),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  if (_isStarting)
                                    _SetupSection(
                                      summary: summary,
                                      onOpenMoney: onOpenMoney,
                                      onOpenTasks: onOpenTasks,
                                      onOpenGuests: onOpenGuests,
                                    ),
                                  if (_isStarting && _showsSharing) ...[
                                    const SizedBox(height: AppTheme.space24),
                                  ],
                                  if (_showsSharing)
                                    _SharingSection(
                                      summary: summary,
                                      onOpenSharing: onOpenSharing,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: AppTheme.space10),
                        AarastMotionSwitcher(
                          alignment: AlignmentDirectional.centerStart,
                          child: _DashboardMobileMosaic(
                            key: ValueKey('mosaic-${summary.planId}'),
                            focus: focus,
                            summary: summary,
                            onOpenFocus: () => _openFocus(focus),
                            onOpenMoney: onOpenMoney,
                            onOpenTasks: onOpenTasks,
                            onOpenGuests: onOpenGuests,
                            onOpenProviders: onOpenProviders,
                            onOpenSharing: onOpenSharing,
                            showSharing: _showsSharing,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool get _showsSharing =>
      summary.permissions.isOwner || summary.permissions.canManageMembers;

  void _openFocus(AarastDashboardFocus focus) {
    switch (focus.target) {
      case AarastDashboardFocusTarget.item:
        final item = focus.item;
        if (item != null) {
          onOpenImportantItem(item);
        } else {
          onOpenNextStep();
        }
      case AarastDashboardFocusTarget.plan:
        onOpenPlan();
      case AarastDashboardFocusTarget.money:
        onOpenMoney();
      case AarastDashboardFocusTarget.tasks:
        onOpenTasks();
      case AarastDashboardFocusTarget.guests:
        onOpenGuests();
      case AarastDashboardFocusTarget.providers:
        onOpenProviders();
      case AarastDashboardFocusTarget.sharing:
        onOpenSharing();
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.avatarUrl,
    required this.summary,
    required this.onNotifications,
    required this.onProfile,
    required this.now,
  });

  final String userName;
  final String? avatarUrl;
  final DashboardSummary summary;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final DateTime? now;

  String get _greeting {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير';
    if (hour >= 12 && hour < 17) return 'مساء النور';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _greeting,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (summary.isLocalOnly) ...[
              const SizedBox(width: AppTheme.space8),
              const _LocalStateBadge(),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          userName,
          maxLines: 2,
          overflow: TextOverflow.fade,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AarastHeaderIconAction(
          key: const ValueKey('dashboard-notifications-action'),
          icon: LucideIcons.bell,
          label: 'التنبيهات',
          badgeCount: summary.unreadNotificationsCount,
          onTap: onNotifications,
        ),
        const SizedBox(width: AppTheme.space4),
        AarastHeaderAvatarAction(
          key: const ValueKey('dashboard-profile-action'),
          userName: userName,
          avatarUrl: avatarUrl,
          onTap: onProfile,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppTheme.space12),
        actions,
      ],
    );
  }
}

class _PlanMoment extends StatelessWidget {
  const _PlanMoment({
    required this.summary,
    required this.stage,
    required this.personaHeadline,
    required this.onTap,
  });

  final DashboardSummary summary;
  final WeddingPlanStageState stage;
  final String? personaHeadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = summary.daysRemaining;
    final dateLabel = _dateLabel(summary.weddingDate);
    final locationLabel = _locationLabel(summary);
    final progress = summary.progressPercentage.clamp(0, 100);

    return AarastPressable(
      key: const ValueKey('aarast-dashboard-plan-moment'),
      onTap: onTap,
      semanticLabel: 'فتح إدارة الخطة: ${summary.title}',
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 146),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AarastV3Color.primary,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: Border.all(color: AarastV3Color.primaryDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AarastV3Color.brandAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personaHeadline?.trim().isNotEmpty == true
                              ? '${personaHeadline!.trim()} · ${stage.compactLabel}'
                              : stage.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AarastV3Type.label(
                            context,
                          ).copyWith(color: AarastV3Color.brandAccent),
                        ),
                        const SizedBox(height: AarastV3Space.x1),
                        Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AarastV3Type.section(context).copyWith(
                            color: AarastV3Color.onPrimary,
                            fontSize: 20,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        days == null ? '—' : '${days.clamp(0, 9999)}',
                        style: AarastV3Type.display(context).copyWith(
                          color: AarastV3Color.brandAccent,
                          fontSize: 35,
                          height: .9,
                        ),
                      ),
                      Text(
                        days == null ? 'دون موعد' : 'يوم',
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: AarastV3Color.onPrimaryMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x4),
              if (dateLabel?.isNotEmpty == true) ...[
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 14,
                      color: AarastV3Color.onPrimaryMuted,
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Text(
                        dateLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: AarastV3Color.onPrimaryMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x1),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (locationLabel?.isNotEmpty == true) ...[
                    Icon(
                      LucideIcons.mapPin,
                      size: 14,
                      color: AarastV3Color.onPrimaryMuted,
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Text(
                        locationLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: AarastV3Color.onPrimaryMuted),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const SizedBox(width: AarastV3Space.x3),
                  Text(
                    'إنجاز $progress%',
                    style: AarastV3Type.label(context).copyWith(
                      color: AarastV3Color.brandAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              AarastV3PlanPath(
                value: progress / 100,
                semanticsLabel: 'مسار تقدّم خطة ${summary.title}',
                color: AarastV3Color.brandAccent,
                trackColor: AarastV3Color.onPrimaryMuted.withValues(alpha: .3),
                nodeFillColor: AarastV3Color.primary,
                inactiveNodeColor: AarastV3Color.onPrimaryMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeddingDayEntry extends StatelessWidget {
  const _WeddingDayEntry({required this.status, required this.onTap});

  final WeddingDayModeStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = status.phase == WeddingDayPhase.today;
    return AarastPressable(
      key: const Key('wedding-day-mode-entry'),
      onTap: onTap,
      semanticLabel: status.dashboardLabel,
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x3,
          vertical: AarastV3Space.x2,
        ),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(
            color: isToday ? AarastV3Color.primary : AarastV3Color.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AarastV3Color.primarySoft,
                borderRadius: BorderRadius.circular(AarastV3Radius.control),
              ),
              child: const Icon(
                LucideIcons.calendarHeart,
                color: AarastV3Color.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.eyebrow,
                    style: AarastV3Type.label(
                      context,
                    ).copyWith(color: AarastV3Color.primary),
                  ),
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    status.dashboardLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AarastV3Color.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            const Icon(
              LucideIcons.chevronLeft,
              color: AarastV3Color.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
