part of 'aarast_dashboard_view.dart';

class _DashboardTeamStrip extends StatelessWidget {
  const _DashboardTeamStrip({required this.summary, required this.onTap});

  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final participantsLabel = '${summary.participantCount} مشاركين';
    final invitesLabel = '${summary.pendingInvites} دعوات بانتظار الرد';
    return AarastPressable(
      key: const ValueKey('aarast-dashboard-sharing'),
      onTap: onTap,
      semanticLabel: summary.pendingInvites > 0
          ? 'فريق الخطة، $participantsLabel، $invitesLabel'
          : 'فريق الخطة، $participantsLabel',
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space6,
        ),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.users,
              size: 20,
              color: AarastV3Color.primary,
            ),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فريق الخطة',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Row(
                    children: [
                      Text(
                        participantsLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (summary.pendingInvites > 0) ...[
                        const SizedBox(width: AppTheme.space6),
                        Expanded(
                          child: Text(
                            invitesLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AarastV3Color.amber,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            const Icon(
              LucideIcons.arrowLeft,
              size: 17,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalStateBadge extends StatelessWidget {
  const _LocalStateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: AarastSemanticTokens.warningMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Text(
        'محلي',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AarastSemanticTokens.warning,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.brand,
        minimumSize: const Size(48, 48),
      ),
      child: Text(label),
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          value,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String? _dateLabel(DateTime? date) {
  if (date == null) return null;
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

String? _locationLabel(DashboardSummary summary) {
  final fullLabel = summary.location?['fullLabel']?.toString().trim();
  if (fullLabel != null && fullLabel.isNotEmpty) return fullLabel;
  final city = summary.city?.trim();
  return city == null || city.isEmpty ? null : city;
}
