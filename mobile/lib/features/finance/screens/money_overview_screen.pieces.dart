part of 'money_overview_screen.dart';

enum _MoneySettingsAction { budget, receipts }

class _MoneyHeader extends StatelessWidget {
  const _MoneyHeader({
    required this.summary,
    required this.showStatus,
    required this.canManage,
    required this.onShare,
    required this.onBudget,
    required this.onReceipts,
  });

  final MoneySummary summary;

  /// The budget state under «المال»; off where the tab says it itself.
  final bool showStatus;
  final bool canManage;
  final VoidCallback? onShare;
  final VoidCallback onBudget;

  /// Null where receipts cannot be kept (a guest's plan on the phone).
  final VoidCallback? onReceipts;

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
              if (showStatus)
                Text(
                  _moneyStatusLine(summary, context.journeyProfile),
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
          const SizedBox(width: AarastV3Space.x1),
          JourneyRoundButton(
            key: const Key('money-share-summary'),
            icon: LucideIcons.share2,
            tooltip: context.say(
              'شارك الملخص على واتساب',
              'شاركي الملخص على واتساب',
            ),
            onPressed: onShare!,
          ),
        ],
        if (canManage || onReceipts != null) ...[
          const SizedBox(width: AarastV3Space.x1),
          _MoneySettingsMenu(
            canManage: canManage,
            onBudget: onBudget,
            onReceipts: onReceipts,
          ),
        ],
      ],
    );
  }
}

class _MoneySettingsMenu extends StatelessWidget {
  const _MoneySettingsMenu({
    required this.canManage,
    required this.onBudget,
    required this.onReceipts,
  });

  final bool canManage;
  final VoidCallback onBudget;
  final VoidCallback? onReceipts;

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
            case _MoneySettingsAction.receipts:
              onReceipts?.call();
          }
        },
        itemBuilder: (context) => [
          if (canManage)
            const PopupMenuItem(
              key: ValueKey('money-settings-budget'),
              value: _MoneySettingsAction.budget,
              child: _MoneySettingsItem(
                icon: LucideIcons.walletCards,
                label: 'الميزانية والبنود',
              ),
            ),
          if (onReceipts != null)
            const PopupMenuItem(
              key: ValueKey('money-settings-receipts'),
              value: _MoneySettingsAction.receipts,
              child: _MoneySettingsItem(
                icon: LucideIcons.receipt,
                label: 'الإيصالات',
              ),
            ),
        ],
        // A round icon like the other header actions: a word beside three
        // buttons does not fit a 320-point phone with large text.
        // The 44 circle in a 48 target, like the round buttons beside it.
        child: SizedBox.square(
          dimension: AarastV3Space.x12,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AarastV3Color.paper,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.slidersHorizontal,
                size: 18,
                color: AarastV3Color.ink,
              ),
            ),
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
        const SizedBox(width: AarastV3Space.x2),
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
    final isOverdue = schedule.isOverdueAt(appNow());
    final color = isOverdue
        ? AarastV3Color.danger
        : AarastV3Color.brandAccentStrong;
    final soft = isOverdue
        ? AarastV3Color.dangerSoft
        : AarastV3Color.brandAccentSoft;
    // RA-BE-53: what paying it records, not more than the agreement owes.
    final amount = _amount(context, schedule.dueAmount, currency);
    return Semantics(
      button: true,
      label:
          '${isOverdue ? 'دفعة متأخرة' : 'الدفعة الجاية'}، ${schedule.costTitle ?? 'دفعة'}، $amount، ${formatArabicWeekdayDayMonth(schedule.dueDate)}',
      onTap: onTap,
      child: AarastPressable(
        key: const ValueKey('money-next-schedule-strip'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: JourneyBox(
          padding: const EdgeInsets.all(AarastV3Space.x4),
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
                    const SizedBox(width: AarastV3Space.x3),
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
                const SizedBox(height: AarastV3Space.x3),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyButton(
                    // RA-MO-27: the plan's colour, as the same action on a
                    // late row in the payments list; the red is the late
                    // line's, not a destructive button's.
                    label: context.say('سجّل الدفعة', 'سجّلي الدفعة'),
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
