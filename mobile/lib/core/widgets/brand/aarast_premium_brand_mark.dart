import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_theme.dart';

class AarastPremiumBrandMark extends StatelessWidget {
  const AarastPremiumBrandMark({super.key});

  static const semanticsLabel = 'اعّرست، كل ما يخص الزفاف في مكان واحد';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: AppTheme.burgundyDeep.withValues(alpha: 0.3),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.gold, AppTheme.gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: AppTheme.ivory,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'اعّرست',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.burgundy,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: AppTheme.burgundyDark.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  Shadow(
                    color: AppTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'كل ما يخص الزفاف في مكان واحد',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
