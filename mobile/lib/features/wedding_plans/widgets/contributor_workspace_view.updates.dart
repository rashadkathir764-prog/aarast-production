part of 'contributor_workspace_view.dart';

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
