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
