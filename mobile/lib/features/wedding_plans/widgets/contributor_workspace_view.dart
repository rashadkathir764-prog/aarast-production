import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/dashboard_summary.dart';
import 'dashboard/aarast_dashboard_focus.dart';

part 'contributor_workspace_view.sections.dart';
part 'contributor_workspace_view.updates.dart';

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
          title: 'المزودين',
          value: '${summary.providerCount} مزود',
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
