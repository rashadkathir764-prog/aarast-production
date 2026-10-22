part of 'aarast_dashboard_view.dart';

class _FocusPanel extends StatelessWidget {
  const _FocusPanel({required this.focus, required this.onTap, super.key});

  final AarastDashboardFocus focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastV3AttentionSurface(
      eyebrow: focus.eyebrow,
      title: focus.title,
      reason: focus.reason,
      icon: focus.icon,
      actionLabel: focus.actionLabel,
      onAction: onTap,
      tone: switch (focus.tone) {
        AarastDashboardFocusTone.urgent => AarastV3AttentionTone.danger,
        AarastDashboardFocusTone.attention => AarastV3AttentionTone.warning,
        AarastDashboardFocusTone.positive => AarastV3AttentionTone.success,
        AarastDashboardFocusTone.calm => AarastV3AttentionTone.calm,
      },
    );
  }
}

class _PlanPulse extends StatelessWidget {
  const _PlanPulse({
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
    return AarastSection(
      title: 'مشهد الخطة',
      description: 'ثلاث إشارات حقيقية تكشف لك أين تقف الآن.',
      child: AarastV3ContinuousSurface(
        children: [
          _PlanSignalRow(
            icon: LucideIcons.listChecks,
            label: 'المهام',
            value: '${summary.completedTasks} من ${summary.totalTasks}',
            caption: summary.overdueTasks > 0
                ? '${summary.overdueTasks} متأخرة وتحتاج انتباهك'
                : summary.todayTasks > 0
                ? '${summary.todayTasks} لليوم'
                : summary.totalTasks == 0
                ? 'ابدأ بأول مهمة واضحة'
                : 'لا توجد مهام متأخرة',
            onTap: onOpenTasks,
            accent: AarastV3Color.amber,
          ),
          _PlanSignalRow(
            icon: LucideIcons.users,
            label: 'الضيوف',
            value: '${summary.guestCount}',
            caption: summary.guestCount == 0
                ? 'ابدأ القائمة'
                : '${summary.confirmedGuests} مؤكّد',
            onTap: onOpenGuests,
            accent: AarastV3Color.cobalt,
          ),
          _PlanSignalRow(
            icon: LucideIcons.store,
            label: 'المزودين',
            value: '${summary.providerCount}',
            caption: summary.receivedQuotes > 0
                ? '${summary.receivedQuotes} عرض وصل'
                : summary.pendingQuoteRequests > 0
                ? '${summary.pendingQuoteRequests} بانتظار رد'
                : 'استكشف المزودين',
            onTap: onOpenProviders,
            accent: AarastV3Color.mint,
          ),
        ],
      ),
    );
  }
}

class _PlanSignalRow extends StatelessWidget {
  const _PlanSignalRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Space.x4,
            vertical: AarastV3Space.x4,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AarastV3Type.label(
                        context,
                      ).copyWith(color: AarastV3Color.ink),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AarastV3Color.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              const Icon(
                LucideIcons.chevronLeft,
                color: AarastV3Color.textFaint,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneySection extends StatelessWidget {
  const _MoneySection({required this.summary, required this.onOpenMoney});

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;

  @override
  Widget build(BuildContext context) {
    final budget = dashboardAmount(summary.totalBudgetForDisplay);
    final confirmed = dashboardAmount(summary.confirmedCostForDisplay) ?? 0;
    final remaining = dashboardAmount(summary.remainingBudgetForDisplay);
    final ratio = budget == null || budget <= 0
        ? null
        : (confirmed / budget).clamp(0.0, 1.0);

    return AarastSection(
      title: 'المال بوضوح',
      description: budget == null
          ? 'الميزانية غير محددة؛ لن نعرضها كصفر.'
          : 'قراءة واحدة للميزانية والتكاليف المؤكدة.',
      action: _SectionAction(label: 'التفاصيل', onTap: onOpenMoney),
      child: AarastSurface(
        onTap: onOpenMoney,
        borderColor: AarastSemanticTokens.border,
        radius: AppTheme.radiusXl,
        elevated: true,
        padding: const EdgeInsets.all(AppTheme.space20),
        child: budget == null
            ? _UnsetBudget(confirmed: confirmed, currency: summary.currency)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppTheme.minTapTarget,
                        height: AppTheme.minTapTarget,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.brandMuted,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSurface,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.walletCards,
                          color: AppTheme.brand,
                          size: AppTheme.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المتبقي',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.space2),
                            Text(
                              remaining == null
                                  ? 'غير محسوب'
                                  : _money(remaining, summary.currency),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: (remaining ?? 0) < 0
                                        ? AarastSemanticTokens.danger
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.arrowUpLeft,
                        color: AppTheme.textSecondary,
                        size: AppTheme.iconMd,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          confirmed > budget
                              ? 'تجاوزت الميزانية'
                              : ratio == null
                              ? 'لم يبدأ الصرف'
                              : 'مستخدم ${(ratio * 100).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: confirmed > budget
                                    ? AarastSemanticTokens.danger
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        'الميزانية',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  AarastV3ProgressLine(
                    height: 6,
                    value: ratio,
                    color: confirmed > budget
                        ? AarastSemanticTokens.danger
                        : AppTheme.brand,
                    backgroundColor: AppTheme.surfaceMuted,
                    semanticsLabel: 'استهلاك الميزانية',
                  ),
                  const SizedBox(height: AppTheme.space20),
                  Row(
                    children: [
                      Expanded(
                        child: _MoneyMetric(
                          label: 'الميزانية',
                          value: _money(budget, summary.currency),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Expanded(
                        child: _MoneyMetric(
                          label: 'التكاليف المؤكدة',
                          value: _money(confirmed, summary.currency),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.summary,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenGuests,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;

  @override
  Widget build(BuildContext context) {
    final steps = <_SetupStepData>[
      if (summary.permissions.canViewMoney)
        _SetupStepData(
          label: 'حدّد الميزانية',
          done: dashboardAmount(summary.totalBudgetForDisplay) != null,
          onTap: onOpenMoney,
        ),
      _SetupStepData(
        label: 'أضف أول مهمة',
        done: summary.totalTasks > 0,
        onTap: onOpenTasks,
      ),
      _SetupStepData(
        label: 'ابدأ قائمة الضيوف',
        done: summary.guestCount > 0,
        onTap: onOpenGuests,
      ),
    ];
    final completed = steps.where((step) => step.done).length;

    return AarastSection(
      title: 'تجهيز الأساس',
      description: '$completed من ${steps.length} خطوات مكتملة',
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space16),
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: AarastSemanticTokens.border),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'جاهزية الانطلاق',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  '${((completed / steps.length) * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            AarastV3ProgressLine(
              height: 6,
              value: completed / steps.length,
              color: AppTheme.brand,
              backgroundColor: AppTheme.surfaceMuted,
              semanticsLabel: 'تقدم تجهيز الخطة',
            ),
            const SizedBox(height: AppTheme.space8),
            for (var index = 0; index < steps.length; index++) ...[
              _SetupRow(step: steps[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SharingSection extends StatelessWidget {
  const _SharingSection({required this.summary, required this.onOpenSharing});

  final DashboardSummary summary;
  final VoidCallback onOpenSharing;

  @override
  Widget build(BuildContext context) {
    return AarastSection(
      title: 'فريق الخطة',
      description: 'المشاركة والصلاحيات في مكان واحد.',
      child: AarastPressable(
        key: const ValueKey('aarast-dashboard-sharing'),
        onTap: onOpenSharing,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AarastSemanticTokens.border),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.users,
                color: AppTheme.brand,
                size: AppTheme.iconLg,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.participantCount} مشاركين',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      summary.pendingInvites == 0
                          ? 'لا توجد دعوات معلقة'
                          : '${summary.pendingInvites} دعوات بانتظار الرد',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.arrowLeft,
                color: AppTheme.textSecondary,
                size: AppTheme.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.step});

  final _SetupStepData step;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: step.onTap,
      semanticLabel: '${step.label}، ${step.done ? 'مكتملة' : 'غير مكتملة'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: step.done
                    ? AarastSemanticTokens.successMuted
                    : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Icon(
                step.done ? LucideIcons.check : LucideIcons.circle,
                color: step.done
                    ? AarastSemanticTokens.success
                    : AppTheme.textDisabled,
                size: AppTheme.iconSm,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                step.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: step.done
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  decoration: step.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.textSecondary,
              size: AppTheme.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsetBudget extends StatelessWidget {
  const _UnsetBudget({required this.confirmed, required this.currency});

  final double confirmed;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppTheme.minTapTarget,
          height: AppTheme.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.brandMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          child: const Icon(
            LucideIcons.walletCards,
            color: AppTheme.brand,
            size: AppTheme.iconMd,
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الميزانية غير محددة',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                confirmed > 0
                    ? 'التكاليف المؤكدة: ${_money(confirmed, currency)}'
                    : 'أضف رقمًا تقريبيًا متى أصبحت جاهزًا.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const Icon(
          LucideIcons.arrowLeft,
          color: AppTheme.textSecondary,
          size: AppTheme.iconMd,
        ),
      ],
    );
  }
}

class _SetupStepData {
  const _SetupStepData({
    required this.label,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool done;
  final VoidCallback onTap;
}

String _money(double value, String currency) {
  return compactMoneyParts(value, currencyCode: currency).plainText;
}
