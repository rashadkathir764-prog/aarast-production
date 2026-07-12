import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import 'smart_dashboard_models.dart';

class AarastNextActionCard extends StatelessWidget {
  const AarastNextActionCard({
    required this.action,
    required this.onTap,
    super.key,
  });

  final SmartAction action;
  final VoidCallback onTap;

  Color get _accent => switch (action.tone) {
    SmartActionTone.urgent => AarastDesignTokens.danger,
    SmartActionTone.attention => AarastDesignTokens.gold,
    SmartActionTone.celebrate => AarastDesignTokens.success,
    SmartActionTone.calm => AarastDesignTokens.info,
  };

  Color get _accentSoft => switch (action.tone) {
    SmartActionTone.urgent => AarastDesignTokens.dangerSoft,
    SmartActionTone.attention => AarastDesignTokens.goldSoft,
    SmartActionTone.celebrate => AarastDesignTokens.successSoft,
    SmartActionTone.calm => AarastDesignTokens.infoSoft,
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final textTheme = Theme.of(context).textTheme;

    Widget iconBadge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
      child: Icon(action.icon, color: _accent, size: 22),
    );

    if (!reduceMotion && action.tone == SmartActionTone.urgent) {
      iconBadge = iconBadge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.07, 1.07),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(color: AarastDesignTokens.border),
            boxShadow: [
              BoxShadow(
                color: AarastDesignTokens.ink.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            child: Stack(
              children: [
                // العمود اللوني — الأولوية تُقرأ قبل أي كلمة.
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: _accent),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 14),
                  child: Row(
                    children: [
                      iconBadge,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الخطوة الذكية',
                              style: textTheme.labelSmall?.copyWith(
                                color: _accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              action.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: AarastDesignTokens.ink,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              action.reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: AarastDesignTokens.muted,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 20,
                        color: AarastDesignTokens.muted.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
