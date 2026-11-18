part of 'money_overview_screen.dart';

enum _MoneySettingsAction { share, budget, receipts }

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
                    JourneyType.pageTitle,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              if (showStatus
                      ? _moneyStatusLine(summary, context.journeyProfile)
                      : null
                  case final line?)
                Text(
                  line,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
        ),
        const MoneyPrivacyButton(),
        // The share is in «⋯» with its name (critique م8): its round button
        // left the eye no room for its word.
        if (canManage || onReceipts != null || onShare != null) ...[
          const SizedBox(width: AarastV3Space.x1),
          _MoneySettingsMenu(
            canManage: canManage,
            onBudget: onBudget,
            onReceipts: onReceipts,
            onShare: onShare,
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
    required this.onShare,
  });

  final bool canManage;
  final VoidCallback onBudget;
  final VoidCallback? onReceipts;
  final VoidCallback? onShare;

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
            case _MoneySettingsAction.share:
              onShare?.call();
          }
        },
        itemBuilder: (context) => [
          if (onShare != null)
            PopupMenuItem(
              key: const ValueKey('money-share-summary'),
              value: _MoneySettingsAction.share,
              child: _MoneySettingsItem(
                icon: LucideIcons.share2,
                label: context.say(
                  'شارك الملخص على واتساب',
                  'شاركي الملخص على واتساب',
                ),
              ),
            ),
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
        // A round icon: the eye beside it carries its word (م8), and two
        // words in a header do not fit a 320-point phone with large text.
        // The 44 circle in a 48 target.
        child: SizedBox.square(
          dimension: AarastV3Space.x12,
          child: Center(
            child: Container(
              width: AarastV3Size.mark,
              height: AarastV3Size.mark,
              decoration: const BoxDecoration(
                color: AarastV3Color.paper,
                shape: BoxShape.circle,
              ),
              // «⋯», the sign for «more»: the sliders read as a filter, and
              // behind them were the budget and the receipts (2026-11-17).
              child: const Icon(
                LucideIcons.moreHorizontal,
                size: AarastV3Icon.md,
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
        Icon(icon, size: AarastV3Icon.md, color: AppTheme.brand),
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
