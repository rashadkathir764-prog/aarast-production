import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import 'smart_dashboard_models.dart';

class AarastSetupJourneyCard extends StatelessWidget {
  const AarastSetupJourneyCard({required this.steps, super.key});

  final List<SetupStep> steps;

  @override
  Widget build(BuildContext context) {
    final doneCount = steps.where((s) => s.done).length;
    final reduceMotion = AarastMotion.reduceMotion(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AarastDesignTokens.surface,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        border: Border.all(
          color: AarastDesignTokens.gold.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.gold.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                color: AarastDesignTokens.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لنجهّز خطتك في ٣ خطوات',
                  style: textTheme.titleMedium?.copyWith(
                    color: AarastDesignTokens.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$doneCount/${steps.length}',
                style: textTheme.labelLarge?.copyWith(
                  color: AarastDesignTokens.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'كل خطوة تفتح لك صورة أوضح ليومك الكبير.',
            style: textTheme.labelMedium?.copyWith(
              color: AarastDesignTokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            _SetupStepRow(
              step: steps[i],
              index: i,
              isLast: i == steps.length - 1,
              reduceMotion: reduceMotion,
            ),
        ],
      ),
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  const _SetupStepRow({
    required this.step,
    required this.index,
    required this.isLast,
    required this.reduceMotion,
  });

  final SetupStep step;
  final int index;
  final bool isLast;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    Widget marker = step.done
        ? Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AarastDesignTokens.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 18),
          )
        : Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AarastDesignTokens.goldSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AarastDesignTokens.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(step.icon, color: AarastDesignTokens.gold, size: 15),
          );

    if (step.done && !reduceMotion) {
      marker = marker
          .animate()
          .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            duration: 450.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms);
    }

    return InkWell(
      onTap: step.done ? null : step.onTap,
      borderRadius: BorderRadius.circular(AarastDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Column(
              children: [
                marker,
                if (!isLast)
                  Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.done
                        ? AarastDesignTokens.success.withValues(alpha: 0.4)
                        : AarastDesignTokens.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 8 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: step.done
                            ? AarastDesignTokens.muted
                            : AarastDesignTokens.ink,
                        fontWeight: FontWeight.w800,
                        decoration: step.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AarastDesignTokens.muted,
                      ),
                    ),
                    if (!step.done) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.hint,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AarastDesignTokens.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!step.done)
              const Padding(
                padding: EdgeInsetsDirectional.only(bottom: 12),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 18,
                  color: AarastDesignTokens.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
