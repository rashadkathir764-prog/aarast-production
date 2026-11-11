part of 'aarast_dashboard_view.dart';

class _DashboardTeamStrip extends StatelessWidget {
  const _DashboardTeamStrip({required this.summary, required this.onTap});

  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final people = arabicCount(
      summary.participantCount,
      one: 'مشارك واحد',
      two: 'مشاركَين',
      few: 'مشاركين',
      many: 'مشارك',
    );
    final invites = arabicCount(
      summary.pendingInvites,
      one: 'دعوة تنتظر الرد',
      two: 'دعوتين تنتظر الرد',
      few: 'دعوات تنتظر الرد',
      many: 'دعوة تنتظر الرد',
    );
    return JourneyBox(
      key: const ValueKey('aarast-dashboard-sharing'),
      borderColor: AarastV3Color.line,
      borderWidth: AarastV3Space.hair,
      padding: EdgeInsets.zero,
      child: JourneyListRow(
        icon: LucideIcons.users,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
        title: 'فريق الخطة',
        subtitle: summary.pendingInvites > 0 ? '$people · $invites' : people,
        trailing: const Icon(
          LucideIcons.chevronLeft,
          size: 18,
          color: AarastV3Color.textFaint,
        ),
        onTap: onTap,
      ),
    );
  }
}
