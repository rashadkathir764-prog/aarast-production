import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';

class GuestOnboardingStepScaffold extends StatelessWidget {
  const GuestOnboardingStepScaffold({
    required this.title,
    required this.description,
    required this.continueLabel,
    required this.child,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final String title;
  final String description;
  final String continueLabel;
  final Widget child;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: onBack ?? () => _maybePop(context),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              tooltip: 'رجوع',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppTheme.dMaroonDeep,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppTheme.dInkSoft,
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 22),
                          child,
                          const SizedBox(height: 22),
                          PrimaryActionButton(
                            label: continueLabel,
                            icon: Icons.arrow_back_rounded,
                            onPressed: onContinue ?? () {},
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: onBack ?? () => _maybePop(context),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('رجوع'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _maybePop(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

class GuestOnboardingCard extends StatelessWidget {
  const GuestOnboardingCard({required this.child, this.color, super.key});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color ?? AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: child,
    );
  }
}

class GuestOnboardingOptionTile extends StatelessWidget {
  const GuestOnboardingOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.selected = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingCard(
      color: selected ? AppTheme.dPinkBg.withAlpha(120) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppTheme.dMaroon : AppTheme.dCreamBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : AppTheme.dMaroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppTheme.dMaroon),
        ],
      ),
    );
  }
}

class GuestOnboardingChipList extends StatelessWidget {
  const GuestOnboardingChipList({required this.labels, super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          FilterChip(
            label: Text(label),
            selected: true,
            onSelected: (_) {},
            selectedColor: AppTheme.dPinkBg,
            checkmarkColor: AppTheme.dMaroon,
          ),
      ],
    );
  }
}
