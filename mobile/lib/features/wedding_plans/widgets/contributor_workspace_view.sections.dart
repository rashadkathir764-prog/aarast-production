part of 'contributor_workspace_view.dart';

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
