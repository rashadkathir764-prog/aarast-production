import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/dashboard_summary.dart';
import 'dashboard/aarast_dashboard_focus.dart';

/// أدوار دلالية لمساحة المساهم مبنية من النظام نفسه، لا من لوحة مستقلة.
abstract final class ContributorWorkspacePalette {
  static const canvas = AppTheme.canvas;
  static const surface = AppTheme.surfaceRaised;
  static const surfaceAlt = AppTheme.surfaceMuted;
  static const border = AppTheme.border;
  static const ink = AppTheme.textPrimary;
  static const muted = AppTheme.textSecondary;
  static const primary = AppTheme.brand;
  static const focus = AppTheme.focus;
  static const focusSoft = AppTheme.infoSoft;
  static const warning = AppTheme.warning;
  static const moneyTint = AppTheme.successSoft;
  static const guestsTint = AppTheme.infoSoft;
  static const providersTint = AppTheme.brandMuted;
}

typedef ContributorWorkspaceColors = ContributorWorkspacePalette;

/// المساحة الوحيدة للمساهم داخل الخطة المشتركة.
///
/// لا تعرض إلا الأقسام المسموحة فعليًا، وتبقي التحديثات والصلاحيات في نفس
/// السياق بدل إنشاء شريط تنقل ثانٍ داخل التطبيق.
class ContributorWorkspaceView extends StatelessWidget {
  const ContributorWorkspaceView({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenNotifications,
    required this.onShowPermissions,
    this.effectivePermissions,
    this.onOpenMoney,
    this.onOpenGuests,
    this.onOpenProviders,
    this.onOpenMembers,
    this.onCreateTask,
    this.onAddGuest,
    this.onAddCost,
    this.onOpenContributionHistory,
    super.key,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenNotifications;
  final VoidCallback onShowPermissions;
  final DashboardPermissionSummary? effectivePermissions;
  final VoidCallback? onOpenMoney;
  final VoidCallback? onOpenGuests;
  final VoidCallback? onOpenProviders;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onCreateTask;
  final VoidCallback? onAddGuest;
  final VoidCallback? onAddCost;
  final VoidCallback? onOpenContributionHistory;

  @override
  Widget build(BuildContext context) {
    final sections = _sections();
    final nextAction = _nextAction();
    final children = <Widget>[
      _ContributorRoleStrip(role: _roleLabel(summary.permissions.role)),
      const SizedBox(height: AppTheme.gapMd),
      _ContributorPlanHero(summary: summary),
      if (nextAction != null) ...[
        const SizedBox(height: AppTheme.gapMd),
        _ContributorNextActionCard(action: nextAction),
      ],
      const SizedBox(height: AppTheme.gapLg),
      const _ContributorSectionHeader(
        title: 'الأقسام المتاحة لك',
        subtitle: 'تتغير هذه الأقسام تلقائيًا حسب صلاحياتك في الخطة.',
        icon: LucideIcons.layoutGrid,
      ),
      const SizedBox(height: AppTheme.gapSm),
      _ContributorSectionsPanel(sections: sections),
      const SizedBox(height: AppTheme.gapLg),
      _ContributorSectionHeader(
        title: 'آخر التحديثات',
        subtitle: summary.unreadNotificationsCount > 0
            ? '${summary.unreadNotificationsCount} تحديثات غير مقروءة'
            : 'كل جديد في الخطة يظهر هنا',
        icon: LucideIcons.bell,
        actionLabel: 'عرض الكل',
        onAction: onOpenNotifications,
      ),
      const SizedBox(height: AppTheme.gapSm),
      _ContributorUpdatesCard(summary: summary, onOpen: onOpenNotifications),
      const SizedBox(height: AppTheme.gapMd),
      if (onOpenContributionHistory != null) ...[
        _ContributorHistoryCard(
          onTap: onOpenContributionHistory!,
          contributionCount: summary.contributionHistory.values.fold<int>(
            0,
            (total, count) => total + count,
          ),
        ),
        const SizedBox(height: AppTheme.gapMd),
      ],
      _ContributorPermissionsCard(onTap: onShowPermissions),
      const SizedBox(height: 32),
    ];

    return ListView(
      key: const PageStorageKey('contributor-workspace-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: AarastStagger.children(context, children),
    );
  }

  List<_ContributorSectionData> _sections() {
    final permissions = effectivePermissions ?? summary.permissions;
    return [
      if (permissions.canManageTasks)
        _ContributorSectionData(
          keyName: 'tasks',
          title: 'المهام',
          value: summary.totalTasks == 0
              ? 'لا توجد مهام'
              : '${summary.totalTasks - summary.completedTasks} غير مكتملة',
          caption: permissions.canManageTasks
              ? 'متابعة المهام وتحديثها'
              : 'مشاهدة مهام الخطة',
          icon: LucideIcons.listChecks,
          tint: ContributorWorkspaceColors.focusSoft,
          onTap: onOpenTasks,
          actionLabel: permissions.canManageTasks ? 'إضافة مهمة' : null,
          onAction: permissions.canManageTasks ? onCreateTask : null,
        ),
      if (permissions.canViewMoney && onOpenMoney != null)
        _ContributorSectionData(
          keyName: 'money',
          title: 'المال',
          value: _moneyValue(summary),
          caption: permissions.canManageMoney
              ? 'عرض التكاليف والدفعات وإدارتها'
              : 'مشاهدة مالية الخطة',
          icon: LucideIcons.walletCards,
          tint: ContributorWorkspaceColors.moneyTint,
          onTap: onOpenMoney!,
          actionLabel: permissions.canManageMoney ? 'إضافة تكلفة' : null,
          onAction: permissions.canManageMoney ? onAddCost : null,
        ),
      if (permissions.canManageGuests && onOpenGuests != null)
        _ContributorSectionData(
          keyName: 'guests',
          title: 'الضيوف',
          value: '${summary.guestCount} ضيفًا',
          caption: 'إدارة القائمة وحالة الحضور',
          icon: LucideIcons.users,
          tint: ContributorWorkspaceColors.guestsTint,
          onTap: onOpenGuests!,
          actionLabel: 'إضافة ضيف',
          onAction: onAddGuest,
        ),
      if (permissions.canManageProviders && onOpenProviders != null)
        _ContributorSectionData(
          keyName: 'providers',
          title: 'الموردون',
          value: '${summary.providerCount} مورد',
          caption: summary.receivedQuotes > 0
              ? '${summary.receivedQuotes} عروض وصلت'
              : 'الخدمات وعروض الأسعار',
          icon: LucideIcons.store,
          tint: ContributorWorkspaceColors.providersTint,
          onTap: onOpenProviders!,
        ),
      if (permissions.canManageMembers && onOpenMembers != null)
        _ContributorSectionData(
          keyName: 'members',
          title: 'المشاركون',
          value: '${summary.participantCount} مشاركين',
          caption: 'الأدوار والصلاحيات',
          icon: LucideIcons.userCog,
          tint: ContributorWorkspaceColors.focusSoft,
          onTap: onOpenMembers!,
        ),
    ];
  }

  _ContributorNextAction? _nextAction() {
    final permissions = effectivePermissions ?? summary.permissions;
    if (permissions.canManageTasks && summary.overdueTasks > 0) {
      return _ContributorNextAction(
        eyebrow: 'يحتاج انتباهك الآن',
        title: summary.overdueTasks == 1
            ? 'مهمة متأخرة في الخطة'
            : '${summary.overdueTasks} مهام متأخرة في الخطة',
        caption: 'راجع الموعد والحالة حتى يبقى العمل مرتبًا.',
        icon: LucideIcons.clock3,
        onTap: onOpenTasks,
      );
    }
    if (permissions.canManageTasks && summary.todayTasks > 0) {
      return _ContributorNextAction(
        eyebrow: 'مهام اليوم',
        title: summary.todayTasks == 1
            ? 'مهمة واحدة تستحق المتابعة'
            : '${summary.todayTasks} مهام تستحق المتابعة',
        caption: 'افتح المهام وراجع ما تم إنجازه اليوم.',
        icon: LucideIcons.calendarCheck,
        onTap: onOpenTasks,
      );
    }
    if (permissions.canViewMoney &&
        (summary.duePaymentSchedulesCount ?? 0) > 0 &&
        onOpenMoney != null) {
      return _ContributorNextAction(
        eyebrow: 'موعد دفع قريب',
        title:
            '${summary.duePaymentSchedulesCount} مواعيد دفع بانتظار المتابعة',
        caption: 'راجع الموعد من سجل المال قبل حلول التاريخ.',
        icon: LucideIcons.calendarClock,
        onTap: onOpenMoney!,
      );
    }
    if (permissions.canManageProviders &&
        summary.receivedQuotes > 0 &&
        onOpenProviders != null) {
      return _ContributorNextAction(
        eyebrow: 'وصل جديد',
        title: summary.receivedQuotes == 1
            ? 'وصل عرض سعر جديد'
            : 'وصلت ${summary.receivedQuotes} عروض أسعار',
        caption: 'راجع التفاصيل وقارن الخيارات قبل اتخاذ القرار.',
        icon: LucideIcons.badgeDollarSign,
        onTap: onOpenProviders!,
      );
    }
    if (summary.unreadNotificationsCount > 0) {
      return _ContributorNextAction(
        eyebrow: 'تحديثات جديدة',
        title: '${summary.unreadNotificationsCount} تحديثات غير مقروءة',
        caption: 'اطلع على آخر ما تغيّر داخل الخطة.',
        icon: LucideIcons.bellRing,
        onTap: onOpenNotifications,
      );
    }
    return null;
  }
}

class _ContributorHistoryCard extends StatelessWidget {
  const _ContributorHistoryCard({
    required this.onTap,
    required this.contributionCount,
  });

  final VoidCallback onTap;
  final int contributionCount;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      key: const Key('contributor-history-card'),
      color: ContributorWorkspaceColors.surface,
      border: Border.all(color: ContributorWorkspaceColors.border),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            LucideIcons.history,
            color: ContributorWorkspaceColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contributionCount > 0
                      ? 'سجل مساهماتي • $contributionCount'
                      : 'سجل مساهماتي',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ContributorWorkspaceColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'نسخة محفوظة من الأعمال التي أنشأتها أو أُسندت إليك أو أنجزتها.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ContributorWorkspaceColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronLeft,
            color: ContributorWorkspaceColors.muted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ContributorRoleStrip extends StatelessWidget {
  const _ContributorRoleStrip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: ContributorWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: ContributorWorkspaceColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.users,
            size: 17,
            color: ContributorWorkspaceColors.warning,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ContributorWorkspaceColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorPlanHero extends StatelessWidget {
  const _ContributorPlanHero({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final date = summary.weddingDate;
    return Container(
      key: const Key('contributor-plan-hero'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              LucideIcons.heart,
              color: AppTheme.brand,
              size: 21,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            summary.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontFamily: AppTheme.displayFontFamily,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(width: 78, height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              if (date != null)
                _HeroMeta(
                  icon: LucideIcons.calendarDays,
                  label: formatArabicCompactDate(date),
                ),
              if (summary.daysRemaining != null && summary.daysRemaining! >= 0)
                _HeroMeta(
                  icon: LucideIcons.hourglass,
                  label: 'باقي ${summary.daysRemaining} يومًا',
                ),
              if (summary.city?.trim().isNotEmpty == true)
                _HeroMeta(
                  icon: LucideIcons.mapPin,
                  label: summary.city!.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 15, color: AppTheme.brand),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributorNextActionCard extends StatelessWidget {
  const _ContributorNextActionCard({required this.action});

  final _ContributorNextAction action;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      key: const Key('contributor-next-action'),
      color: ContributorWorkspaceColors.surface,
      border: Border.all(color: ContributorWorkspaceColors.border),
      onTap: action.onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ContributorWorkspaceColors.focusSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: ContributorWorkspaceColors.focus.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              action.icon,
              color: ContributorWorkspaceColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ContributorWorkspaceColors.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ContributorWorkspaceColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ContributorWorkspaceColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.arrowLeft,
            color: ContributorWorkspaceColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _ContributorSectionHeader extends StatelessWidget {
  const _ContributorSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel != null && onAction != null
        ? TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: ContributorWorkspaceColors.primary,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction =
            action != null &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth < 360;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ContributorWorkspaceColors.focusSoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: ContributorWorkspaceColors.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: ContributorWorkspaceColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ContributorWorkspaceColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null && !stackAction) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
            if (stackAction) ...[
              const SizedBox(height: 4),
              Align(alignment: AlignmentDirectional.centerStart, child: action),
            ],
          ],
        );
      },
    );
  }
}

class _ContributorSectionsPanel extends StatelessWidget {
  const _ContributorSectionsPanel({required this.sections});

  final List<_ContributorSectionData> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const KeyedSubtree(
        key: Key('contributor-sections-panel'),
        child: AarastCard(
          key: Key('contributor-no-live-sections'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.archive,
                color: ContributorWorkspaceColors.warning,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'لا توجد أقسام مباشرة متاحة حاليًا. يمكنك الرجوع إلى سجل مساهماتك المحفوظ أدناه.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth >= 460 &&
            sections.length > 1;
        final cards = sections
            .map((section) => _ContributorSectionRow(section: section))
            .toList(growable: false);

        return KeyedSubtree(
          key: const Key('contributor-sections-panel'),
          child: useGrid
              ? Wrap(
                  spacing: AppTheme.gapSm,
                  runSpacing: AppTheme.gapSm,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: (constraints.maxWidth - AppTheme.gapSm) / 2,
                        child: card,
                      ),
                  ],
                )
              : Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      cards[index],
                      if (index != cards.length - 1)
                        const SizedBox(height: AppTheme.gapSm),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ContributorSectionRow extends StatelessWidget {
  const _ContributorSectionRow({required this.section});

  final _ContributorSectionData section;

  @override
  Widget build(BuildContext context) {
    final hasAction = section.actionLabel != null && section.onAction != null;

    return AarastCard(
      key: Key('contributor-${section.keyName}-section'),
      padding: EdgeInsets.zero,
      color: ContributorWorkspaceColors.surface,
      radius: AppTheme.radiusXl,
      border: Border.all(color: ContributorWorkspaceColors.border),
      onTap: section.onTap,
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(width: 4, color: section.tint),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: section.tint,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      section.icon,
                      color: ContributorWorkspaceColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                section.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: ContributorWorkspaceColors.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                section.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: ContributorWorkspaceColors.focus,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          section.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: ContributorWorkspaceColors.muted,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.arrowLeft,
                              color: ContributorWorkspaceColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'عرض القسم',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: ContributorWorkspaceColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasAction) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: Key('contributor-${section.keyName}-add-action'),
                    onPressed: section.onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: ContributorWorkspaceColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: Text(
                      section.actionLabel!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributorUpdatesCard extends StatelessWidget {
  const _ContributorUpdatesCard({required this.summary, required this.onOpen});

  final DashboardSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final notifications = summary.importantNotifications.take(3).toList();
    final activity = summary.recentActivity.take(3).toList();

    if (notifications.isEmpty && activity.isEmpty) {
      return AarastCard(
        key: const Key('contributor-updates-empty'),
        color: ContributorWorkspaceColors.surface,
        border: Border.all(color: ContributorWorkspaceColors.border),
        onTap: onOpen,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: ContributorWorkspaceColors.moneyTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCheck,
                color: AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لا توجد تحديثات جديدة',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: ContributorWorkspaceColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'سنخبرك هنا عند حدوث تغيير مسموح لك برؤيته.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ContributorWorkspaceColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final rows = notifications.isNotEmpty
        ? notifications
              .map(
                (item) => _UpdateRowData(
                  title: item.title,
                  body: item.body,
                  isUnread: item.readAt == null,
                ),
              )
              .toList()
        : activity
              .map(
                (item) => _UpdateRowData(
                  title: item.title,
                  body: item.subtitle,
                  isUnread: false,
                ),
              )
              .toList();

    return AarastCard(
      key: const Key('contributor-updates-card'),
      color: ContributorWorkspaceColors.surface,
      border: Border.all(color: ContributorWorkspaceColors.border),
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _ContributorUpdateRow(data: rows[i]),
            if (i != rows.length - 1)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: ContributorWorkspaceColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _ContributorUpdateRow extends StatelessWidget {
  const _ContributorUpdateRow({required this.data});

  final _UpdateRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.isUnread
                  ? ContributorWorkspaceColors.focusSoft
                  : ContributorWorkspaceColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.isUnread ? LucideIcons.bell : LucideIcons.history,
              color: ContributorWorkspaceColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ContributorWorkspaceColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (data.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ContributorWorkspaceColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronLeft,
            color: ContributorWorkspaceColors.muted,
            size: 17,
          ),
        ],
      ),
    );
  }
}

class _ContributorPermissionsCard extends StatelessWidget {
  const _ContributorPermissionsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      key: const Key('contributor-permissions-card'),
      color: ContributorWorkspaceColors.surfaceAlt,
      border: Border.all(color: ContributorWorkspaceColors.border),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            color: ContributorWorkspaceColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صلاحياتك واضحة ومحددة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ContributorWorkspaceColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'تظهر لك فقط البيانات والأقسام التي سمح بها مالك الخطة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ContributorWorkspaceColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'عرض',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ContributorWorkspaceColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorSectionData {
  const _ContributorSectionData({
    required this.keyName,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.onTap,
    this.actionLabel,
    this.onAction,
  });

  final String keyName;
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _ContributorNextAction {
  const _ContributorNextAction({
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
}

class _UpdateRowData {
  const _UpdateRowData({
    required this.title,
    required this.body,
    required this.isUnread,
  });

  final String title;
  final String body;
  final bool isUnread;
}

String _roleLabel(String? role) {
  return switch (role?.toUpperCase()) {
    'MANAGER' => 'أنت مساهم في التنظيم',
    'HELPER' => 'أنت مساهم مساعد',
    'VIEWER' => 'أنت مساهم للمتابعة',
    _ => 'أنت مساهم في هذه الخطة',
  };
}

String _moneyValue(DashboardSummary summary) {
  final raw = summary.confirmedCostForDisplay;
  if (raw == null || raw.trim().isEmpty) return 'لا توجد بيانات بعد';
  final value = num.tryParse(raw.replaceAll(',', ''));
  if (value == null) return 'التكاليف متاحة';
  return '${formatDashboardAmount(value)} ${currencyLabelAr(summary.currency)}';
}
