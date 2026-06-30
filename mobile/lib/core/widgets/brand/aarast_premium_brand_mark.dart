import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AarastPremiumBrandMark extends StatelessWidget {
  const AarastPremiumBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -60), // Moved up further as requested
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Subtle glow pedestal
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dGoldDeep.withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: AppTheme.dMaroonDeep.withValues(alpha: 0.3),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
              // Smaller icon (about 15% smaller)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.dGoldDeep, AppTheme.dGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dGold.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1A050A), size: 16), // Dark burgundy icon
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'أعرست',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              height: 1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                Shadow(
                  color: AppTheme.dGold.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'كل ما يخص الزفاف في مكان واحد',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.dGoldDeep.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
