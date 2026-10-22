part of 'money_overview_screen.dart';

enum _MoneySettingsAction { budget, schedules }

class _MoneyCostsSection extends StatelessWidget {
  const _MoneyCostsSection({
    required this.costs,
    required this.currency,
    required this.canManage,
    required this.hasBudget,
    required this.hasMore,
    required this.categoryName,
    required this.onAdd,
    required this.onBudget,
    required this.onAll,
    required this.onOpen,
  });

  final List<WeddingCost> costs;
  final String currency;
  final bool canManage;
  final bool hasBudget;
  final bool hasMore;
  final String? Function(WeddingCost cost) categoryName;
  final VoidCallback onAdd;
  final VoidCallback onBudget;
  final VoidCallback onAll;
  final ValueChanged<WeddingCost> onOpen;

  @override
  Widget build(BuildContext context) {
    final visibleCosts = costs.take(3).toList(growable: false);
    final shouldShowAll = hasMore || costs.length > visibleCosts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'التكاليف',
          subtitle: costs.isEmpty
              ? 'سجّل كل خدمة ومبلغها في بطاقة واحدة.'
              : '${_costCountLabel(costs.length)} مسجلة في الخطة.',
          icon: LucideIcons.receipt,
        ),
        const SizedBox(height: 10),
        if (costs.isEmpty)
          AarastEmptyState(
            icon: LucideIcons.receipt,
            title: 'لا توجد تكاليف بعد',
            message: canManage
                ? 'يمكنك إضافة تكلفة الآن حتى لو لم تحدد الميزانية.'
                : 'لم تُسجل تكاليف في هذه الخطة حتى الآن.',
            action: canManage
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('money-empty-add-cost'),
                        onPressed: onAdd,
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('إضافة تكلفة'),
                      ),
                      if (!hasBudget)
                        TextButton(
                          onPressed: onBudget,
                          child: const Text('تحديد الميزانية'),
                        ),
                    ],
                  )
                : null,
          )
        else ...[
          for (var index = 0; index < visibleCosts.length; index++) ...[
            CostCard(
              key: ValueKey('money-overview-cost-${visibleCosts[index].id}'),
              cost: visibleCosts[index],
              currency: currency,
              categoryName: categoryName(visibleCosts[index]),
              onTap: () => onOpen(visibleCosts[index]),
            ),
            if (index != visibleCosts.length - 1) const SizedBox(height: 2),
          ],
          if (shouldShowAll) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAll,
              icon: const Icon(LucideIcons.arrowLeft, size: 17),
              label: const Text('عرض كل التكاليف'),
            ),
          ],
        ],
      ],
    );
  }
}

/// «المال» with how it stands, then hide, share and manage.
class _MoneyHeader extends StatelessWidget {
  const _MoneyHeader({
    required this.summary,
    required this.canManage,
    required this.onShare,
    required this.onBudget,
    required this.onSchedules,
  });

  final MoneySummary summary;
  final bool canManage;
  final VoidCallback? onShare;
  final VoidCallback onBudget;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'المال',
                  style: JourneyType.of(
                    JourneyType.display,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              Text(
                _moneyStatusLine(summary),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
        const MoneyPrivacyButton(),
        if (onShare != null) ...[
          const SizedBox(width: 6),
          JourneyRoundButton(
            key: const Key('money-share-summary'),
            icon: LucideIcons.share2,
            tooltip: 'شارك الملخص على واتساب',
            onPressed: onShare!,
          ),
        ],
        const SizedBox(width: 6),
        _MoneySettingsMenu(
          canManage: canManage,
          onBudget: onBudget,
          onSchedules: onSchedules,
        ),
      ],
    );
  }
}

class _MoneySettingsMenu extends StatelessWidget {
  const _MoneySettingsMenu({
    required this.canManage,
    required this.onBudget,
    required this.onSchedules,
  });

  final bool canManage;
  final VoidCallback onBudget;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<_MoneySettingsAction>(
        key: const ValueKey('money-settings-menu'),
        tooltip: 'إدارة المال',
        onSelected: (action) {
          switch (action) {
            case _MoneySettingsAction.budget:
              onBudget();
            case _MoneySettingsAction.schedules:
              onSchedules();
          }
        },
        itemBuilder: (context) => [
          if (canManage)
            const PopupMenuItem(
              key: ValueKey('money-settings-budget'),
              value: _MoneySettingsAction.budget,
              child: _MoneySettingsItem(
                icon: LucideIcons.walletCards,
                label: 'الميزانية والتصنيفات',
              ),
            ),
          const PopupMenuItem(
            key: ValueKey('money-settings-schedules'),
            value: _MoneySettingsAction.schedules,
            child: _MoneySettingsItem(
              icon: LucideIcons.calendarClock,
              label: 'مواعيد الدفع',
            ),
          ),
        ],
        child: Container(
          height: 48,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AarastV3Color.paperQuiet,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.slidersHorizontal,
                size: 16,
                color: AarastV3Color.primary,
              ),
              const SizedBox(width: AarastV3Space.x1),
              Text(
                'إدارة',
                style: AarastV3Type.label(
                  context,
                ).copyWith(color: AarastV3Color.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneySettingsItem extends StatelessWidget {
  const _MoneySettingsItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brand),
        const SizedBox(width: AppTheme.space10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({
    required this.schedule,
    required this.currency,
    required this.onTap,
    this.onPay,
  });

  final PaymentSchedule schedule;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final isOverdue = schedule.isOverdueAt(DateTime.now());
    final color = isOverdue
        ? AarastV3Color.danger
        : AarastV3Color.brandAccentStrong;
    final soft = isOverdue
        ? AarastV3Color.dangerSoft
        : AarastV3Color.brandAccentSoft;
    final amount = _amount(context, schedule.amount, currency);
    return Semantics(
      button: true,
      label:
          '${isOverdue ? 'دفعة متأخرة' : 'الدفعة الجاية'}، ${schedule.costTitle ?? 'دفعة'}، $amount، ${formatArabicWeekdayDayMonth(schedule.dueDate)}',
      onTap: onTap,
      child: AarastPressable(
        key: const ValueKey('money-next-schedule-strip'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JourneyIconTile(
                      icon: isOverdue
                          ? LucideIcons.alertCircle
                          : LucideIcons.calendarClock,
                      color: color,
                      soft: soft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOverdue ? 'دفعة متأخرة' : 'الدفعة الجاية',
                            style: JourneyType.of(
                              JourneyType.small,
                              weight: JourneyType.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '${schedule.costTitle ?? 'دفعة'}: $amount',
                            style: JourneyType.of(
                              JourneyType.bodyLarge,
                              weight: JourneyType.bold,
                            ),
                          ),
                          Text(
                            formatArabicWeekdayDayMonth(schedule.dueDate),
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onPay != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyButton(
                    label: 'سجّل الدفعة',
                    background: isOverdue
                        ? AarastV3Color.danger
                        : AarastV3Color.primary,
                    onPressed: onPay,
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

String _costCountLabel(int count) {
  return switch (count) {
    1 => 'تكلفة واحدة',
    2 => 'تكلفتان',
    >= 3 && <= 10 => '$count تكاليف',
    _ => '$count تكلفة',
  };
}
