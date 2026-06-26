import 'package:flutter/material.dart';

import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

class GuestOnboardingStepScaffold extends StatelessWidget {
  const GuestOnboardingStepScaffold({
    required this.title,
    required this.description,
    required this.continueLabel,
    required this.child,
    this.onContinue,
    this.onBack,
    this.stepNumber,
    this.totalSteps = 8,
    super.key,
  });

  final String title;
  final String description;
  final String continueLabel;
  final Widget child;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final int? stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: DecoratedBox(
          decoration: AppTheme.screenDecoration(),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: AarastFadeSlide(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _OnboardingHeader(
                                onBack: onBack,
                                stepNumber: stepNumber,
                                totalSteps: totalSteps,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                title,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppTheme.dInk,
                                      fontFamily: AppTheme.displayFontFamily,
                                      fontSize: 28,
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
                              const SizedBox(height: 20),
                              child,
                              const SizedBox(height: 24),
                              AarastButton(
                                key: const Key(
                                  'guest-onboarding-primary-action',
                                ),
                                label: continueLabel,
                                icon: Icons.arrow_back_rounded,
                                onPressed: onContinue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
  });

  final VoidCallback? onBack;
  final int? stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: onBack == null
              ? null
              : IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  tooltip: 'رجوع',
                ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'أعرست',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.dMaroon,
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (stepNumber != null) ...[
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalSteps, (index) {
                    final active = index < stepNumber!;
                    return AnimatedContainer(
                      duration: AppTheme.motionFast,
                      width: active ? 18 : 7,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.dMaroon : AppTheme.dLine,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 42),
      ],
    );
  }
}

class GuestOnboardingCard extends StatelessWidget {
  const GuestOnboardingCard({required this.child, this.color, super.key});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AarastCard(color: color ?? AppTheme.dCard2, child: child);
  }
}

class GuestOnboardingOptionTile extends StatelessWidget {
  const GuestOnboardingOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.selected = false,
    this.compact = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = GuestOnboardingCard(
      color: selected ? AppTheme.dPinkBg.withAlpha(120) : null,
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.dMaroon : AppTheme.dCreamBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 21,
                        color: selected ? Colors.white : AppTheme.dMaroon,
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: selected ? AppTheme.dMaroon : AppTheme.dLine,
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.dInkSoft),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.dMaroon : AppTheme.dCreamBg,
                    borderRadius: BorderRadius.circular(13),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppTheme.dMaroon : AppTheme.dLine,
                ),
              ],
            ),
    );

    if (onTap == null) return tile;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AarastPressable(
        onTap: onTap!,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        clip: false,
        child: tile,
      ),
    );
  }
}

class GuestOnboardingChipList extends StatelessWidget {
  const GuestOnboardingChipList({
    required this.labels,
    this.selectedLabels,
    this.onChanged,
    super.key,
  });

  final List<String> labels;
  final List<String>? selectedLabels;
  final ValueChanged<List<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLabels ?? labels;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          FilterChip(
            label: Text(label),
            selected: selected.contains(label),
            onSelected: (isSelected) {
              final next = [...selected];
              if (isSelected && !next.contains(label)) {
                next.add(label);
              } else if (!isSelected) {
                next.remove(label);
              }
              onChanged?.call(List.unmodifiable(next));
            },
            selectedColor: AppTheme.dPinkBg,
            checkmarkColor: AppTheme.dMaroon,
          ),
      ],
    );
  }
}
