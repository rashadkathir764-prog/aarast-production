import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/dashboard_summary.dart';
import 'premium/smart_dashboard_models.dart';

/// لوحة ألوان محلية لمساحة المساهم؛ لا تغيّر هوية بقية التطبيق.
abstract final class ContributorWorkspacePalette {
  static const canvas = AppTheme.contributorCanvas;
  static const surface = AppTheme.contributorSurface;
  static const surfaceAlt = AppTheme.contributorSurfaceAlt;
  static const border = AppTheme.contributorBorder;
  static const ink = AppTheme.contributorInk;
  static const muted = AppTheme.contributorMuted;
  static const oxblood = AppTheme.contributorOxblood;
  static const oxbloodDark = AppTheme.contributorOxbloodDark;
  static const wine = AppTheme.contributorWine;
  static const wineSoft = AppTheme.contributorWineSoft;
  static const bronze = AppTheme.contributorBronze;
  static const moneyTint = AppTheme.contributorMoneyTint;
  static const guestsTint = AppTheme.contributorGuestsTint;
  static const providersTint = AppTheme.contributorProvidersTint;
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
    this.onOpenMoney,
    this.onOpenGuests,
    this.onOpenProviders,
    this.onOpenMembers,
    this.onCreateTask,
    this.onAddGuest,
    this.onAddCost,
    super.key,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenNotifications;
  final VoidCallback onShowPermissions;
  final VoidCallback? onOpenMoney;
  final VoidCallback? onOpenGuests;
  final VoidCallback? onOpenProviders;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onCreateTask;
  final VoidCallback? onAddGuest;
  final VoidCallback? onAddCost;

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
    final permissions = summary.permissions;
    return [
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
        tint: ContributorWorkspaceColors.wineSoft,
        onTap: onOpenTasks,
        actionLabel: permissions.canManageTasks ? 'إضافة' : null,
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
          actionLabel: 'إضافة',
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
          tint: ContributorWorkspaceColors.wineSoft,
          onTap: onOpenMembers!,
        ),
    ];
  }

  _ContributorNextAction? _nextAction() {
    if (summary.overdueTasks > 0) {
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
    if (summary.todayTasks > 0) {
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
    if (summary.permissions.canViewMoney &&
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
    if (summary.permissions.canManageProviders &&
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
            color: ContributorWorkspaceColors.bronze,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ContributorWorkspaceColors.oxblood,
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
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            ContributorWorkspaceColors.wine,
            ContributorWorkspaceColors.oxblood,
            ContributorWorkspaceColors.oxbloodDark,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: ContributorWorkspaceColors.bronze.withValues(alpha: 0.64),
        ),
        boxShadow: [
          BoxShadow(
            color: ContributorWorkspaceColors.oxbloodDark.withValues(
              alpha: 0.22,
            ),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: ContributorWorkspaceColors.bronze.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
            child: const Icon(
              LucideIcons.heart,
              color: ContributorWorkspaceColors.bronze,
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
              color: Colors.white,
              fontFamily: AppTheme.displayFontFamily,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 78,
            height: 1,
            color: ContributorWorkspaceColors.bronze.withValues(alpha: 0.78),
          ),
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
        Icon(icon, size: 15, color: ContributorWorkspaceColors.bronze),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
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
              color: ContributorWorkspaceColors.wineSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: ContributorWorkspaceColors.wine.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              action.icon,
              color: ContributorWorkspaceColors.oxblood,
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
                    color: ContributorWorkspaceColors.bronze,
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
            color: ContributorWorkspaceColors.oxblood,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ContributorWorkspaceColors.wineSoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(
            icon,
            color: ContributorWorkspaceColors.oxblood,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: ContributorWorkspaceColors.oxblood,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _ContributorSectionsPanel extends StatelessWidget {
  const _ContributorSectionsPanel({required this.sections});

  final List<_ContributorSectionData> sections;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('contributor-sections-panel'),
      decoration: BoxDecoration(
        color: ContributorWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: ContributorWorkspaceColors.border),
        boxShadow: [
          BoxShadow(
            color: ContributorWorkspaceColors.ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            _ContributorSectionRow(section: sections[index]),
            if (index != sections.length - 1)
              const Divider(
                height: 1,
                indent: 66,
                endIndent: 16,
                color: ContributorWorkspaceColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _ContributorSectionRow extends StatelessWidget {
  const _ContributorSectionRow({required this.section});

  final _ContributorSectionData section;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('contributor-${section.keyName}-section'),
      onTap: section.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: section.tint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    section.icon,
                    color: ContributorWorkspaceColors.oxblood,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: ContributorWorkspaceColors.wine,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ContributorWorkspaceColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
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
            if (section.actionLabel != null && section.onAction != null) ...[
              const SizedBox(height: 7),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: section.onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: ContributorWorkspaceColors.oxblood,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text(section.actionLabel!),
                ),
              ),
            ],
          ],
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
                  ? ContributorWorkspaceColors.wineSoft
                  : ContributorWorkspaceColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.isUnread ? LucideIcons.bell : LucideIcons.history,
              color: ContributorWorkspaceColors.oxblood,
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
            color: ContributorWorkspaceColors.bronze,
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
              color: ContributorWorkspaceColors.oxblood,
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
  return '${formatAmount(value)} ${currencyLabelAr(summary.currency)}';
}
