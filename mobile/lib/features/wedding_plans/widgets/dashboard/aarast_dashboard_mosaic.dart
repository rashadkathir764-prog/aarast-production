part of 'aarast_dashboard_view.dart';

class _DashboardMobileMosaic extends StatelessWidget {
  const _DashboardMobileMosaic({
    required this.focus,
    required this.summary,
    required this.onOpenFocus,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenProviders,
    required this.onOpenSharing,
    required this.showSharing,
    super.key,
  });

  final AarastDashboardFocus focus;
  final DashboardSummary summary;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenSharing;
  final bool showSharing;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('aarast-dashboard-mobile-mosaic'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardFocusCard(focus: focus, onTap: onOpenFocus),
        const SizedBox(height: AarastV3Space.x2),
        _DashboardSignalStrip(
          summary: summary,
          onOpenTasks: onOpenTasks,
          onOpenGuests: onOpenGuests,
          onOpenProviders: onOpenProviders,
        ),
        if (summary.canViewMoney) ...[
          const SizedBox(height: AarastV3Space.x2),
          _DashboardMoneyCard(summary: summary, onTap: onOpenMoney),
        ],
        if (showSharing) ...[
          const SizedBox(height: AarastV3Space.x2),
          _DashboardTeamStrip(summary: summary, onTap: onOpenSharing),
        ],
      ],
    );
  }
}

class _DashboardFocusCard extends StatelessWidget {
  const _DashboardFocusCard({required this.focus, required this.onTap});

  final AarastDashboardFocus focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = _dashboardFocusToneTokens(focus.tone);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final showActionLabel = constraints.maxWidth >= 380 && textScale <= 1.2;

        return Semantics(
          button: true,
          label:
              '${focus.eyebrow}، ${focus.title}. ${focus.reason}. ${focus.actionLabel}',
          child: Material(
            color: AarastV3Color.paper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AarastV3Radius.surface),
              side: const BorderSide(color: AarastV3Color.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('aarast-dashboard-focus-action'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 78),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x3,
                    vertical: AarastV3Space.x2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.foreground,
                          borderRadius: BorderRadius.circular(
                            AarastV3Radius.pill,
                          ),
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          focus.icon,
                          size: 17,
                          color: tokens.foreground,
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              focus.eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: tokens.foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: AarastV3Space.x1),
                            Text(
                              focus.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AarastV3Color.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: AarastV3Space.x1),
                            Text(
                              focus.reason,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AarastV3Color.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      if (showActionLabel) ...[
                        Text(
                          focus.actionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tokens.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(width: AarastV3Space.x1),
                      ],
                      Icon(
                        LucideIcons.chevronLeft,
                        color: tokens.foreground,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardSignalStrip extends StatelessWidget {
  const _DashboardSignalStrip({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenProviders,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenProviders;

  @override
  Widget build(BuildContext context) {
    final remainingTasks = (summary.totalTasks - summary.completedTasks).clamp(
      0,
      summary.totalTasks,
    );
    final cards = [
      _DashboardSignalData(
        key: const ValueKey('dashboard-signal-tasks'),
        icon: LucideIcons.listChecks,
        label: 'المهام',
        value: '$remainingTasks',
        detail: summary.overdueTasks > 0
            ? '${summary.overdueTasks} متأخرة'
            : remainingTasks == 0 && summary.totalTasks > 0
            ? 'مكتملة'
            : 'متبقية',
        accent: summary.overdueTasks > 0
            ? AarastV3Color.rose
            : AarastV3Color.mint,
        heroTag: 'plan-${summary.planId}-tasks',
        onTap: onOpenTasks,
      ),
      _DashboardSignalData(
        key: const ValueKey('dashboard-signal-guests'),
        icon: LucideIcons.users,
        label: 'الضيوف',
        value: '${summary.guestCount}',
        detail: summary.guestCount == 0
            ? 'ابدأ القائمة'
            : summary.incompleteGuestsCount > 0
            ? '${summary.incompleteGuestsCount} ناقص'
            : summary.pendingGuests > 0
            ? '${summary.pendingGuests} ينتظر'
            : '${summary.confirmedGuests} مؤكد',
        accent: summary.guestCount == 0
            ? AarastV3Color.amber
            : AarastV3Color.primary,
        heroTag: 'plan-${summary.planId}-guests',
        onTap: onOpenGuests,
      ),
      _DashboardSignalData(
        key: const ValueKey('dashboard-signal-providers'),
        icon: LucideIcons.store,
        label: 'المزوّدون',
        value: '${summary.providerCount}',
        detail: summary.receivedQuotes > 0
            ? '${summary.receivedQuotes} عرض وصل'
            : summary.pendingQuoteRequests > 0
            ? '${summary.pendingQuoteRequests} ينتظر'
            : summary.providerCount == 0
            ? 'استكشف الآن'
            : 'ضمن الخطة',
        accent: summary.receivedQuotes > 0 || summary.pendingQuoteRequests > 0
            ? AarastV3Color.amber
            : AarastV3Color.cobalt,
        onTap: onOpenProviders,
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: _DashboardSignalCard(data: cards[index])),
            if (index != cards.length - 1)
              const SizedBox(width: AarastV3Space.x2),
          ],
        ],
      ),
    );
  }
}

class _DashboardSignalData {
  const _DashboardSignalData({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    required this.onTap,
    this.heroTag,
  });

  final Key key;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final VoidCallback onTap;
  final Object? heroTag;
}

class _DashboardSignalCard extends StatelessWidget {
  const _DashboardSignalCard({required this.data});

  final _DashboardSignalData data;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return AarastPressable(
      key: data.key,
      onTap: data.onTap,
      semanticLabel: '${data.label}، ${data.value}، ${data.detail}',
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Container(
        constraints: BoxConstraints(minHeight: textScale > 1.3 ? 108 : 94),
        padding: const EdgeInsets.all(AarastV3Space.x2),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AarastV3HeroIcon(
                  icon: data.icon,
                  heroTag: data.heroTag,
                  color: data.accent,
                  size: 16,
                ),
                const SizedBox(width: AarastV3Space.x1),
                Expanded(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AarastV3Color.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AarastV3Space.x2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                data.value,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AarastV3Color.ink,
                  fontFamily: AarastV3Type.displayFamily,
                  fontWeight: FontWeight.w900,
                  height: .95,
                ),
              ),
            ),
            const SizedBox(height: AarastV3Space.x1),
            Text(
              data.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: data.accent,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({Color foreground, Color background}) _dashboardFocusToneTokens(
  AarastDashboardFocusTone tone,
) {
  return switch (tone) {
    AarastDashboardFocusTone.urgent => (
      foreground: AarastV3Color.danger,
      background: AarastV3Color.dangerSoft,
    ),
    AarastDashboardFocusTone.attention => (
      foreground: AarastV3Color.amber,
      background: AarastV3Color.amberSoft,
    ),
    AarastDashboardFocusTone.positive => (
      foreground: AarastV3Color.mint,
      background: AarastV3Color.mintSoft,
    ),
    AarastDashboardFocusTone.calm => (
      foreground: AarastV3Color.primary,
      background: AarastV3Color.primarySoft,
    ),
  };
}
