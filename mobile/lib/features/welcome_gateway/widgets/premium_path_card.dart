import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

/// نغمة بطاقة المسار — تمنح كل مسار لبنة أيقونة متدرّجة فاخرة متناسقة مع
/// هوية أعرست (بورجندي ملكي + ذهب شمبانيا + وردي هادئ) بدل الحلقات
/// الفارغة الباهتة السابقة. المسار الأساسي (النغمة الملكية) هو الأبرز.
enum PremiumPathTone { hero, gold, rose }

class PremiumPathCard extends StatefulWidget {
  const PremiumPathCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = PremiumPathTone.gold,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final PremiumPathTone tone;

  @override
  State<PremiumPathCard> createState() => _PremiumPathCardState();
}

class _PathStyle {
  const _PathStyle({
    required this.tileGradient,
    required this.tileIconColor,
    required this.tileGlow,
    required this.chevronBg,
    required this.chevronColor,
  });

  final Gradient tileGradient;
  final Color tileIconColor;
  final Color tileGlow;
  final Color chevronBg;
  final Color chevronColor;
}

class _PremiumPathCardState extends State<PremiumPathCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  static const _tileGradientBegin = Alignment.topRight;
  static const _tileGradientEnd = Alignment.bottomLeft;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _PathStyle get _style {
    switch (widget.tone) {
      case PremiumPathTone.hero:
        return const _PathStyle(
          tileGradient: LinearGradient(
            begin: _tileGradientBegin,
            end: _tileGradientEnd,
            colors: [
              AppTheme.burgundyLight,
              AppTheme.burgundy,
              AppTheme.burgundyDark,
            ],
          ),
          tileIconColor: Colors.white,
          tileGlow: AppTheme.burgundy,
          chevronBg: AppTheme.goldSoft,
          chevronColor: AppTheme.burgundy,
        );
      case PremiumPathTone.gold:
        return const _PathStyle(
          tileGradient: LinearGradient(
            begin: _tileGradientBegin,
            end: _tileGradientEnd,
            colors: [AppTheme.goldGlow, AppTheme.gold, AppTheme.goldDeep],
          ),
          tileIconColor: AppTheme.burgundyDark,
          tileGlow: AppTheme.gold,
          chevronBg: AppTheme.goldSoft,
          chevronColor: AppTheme.burgundy,
        );
      case PremiumPathTone.rose:
        return const _PathStyle(
          tileGradient: LinearGradient(
            begin: _tileGradientBegin,
            end: _tileGradientEnd,
            colors: [AppTheme.burgundySoft, AppTheme.dangerSoft],
          ),
          tileIconColor: AppTheme.burgundy,
          tileGlow: AppTheme.burgundy,
          chevronBg: AppTheme.burgundySoft,
          chevronColor: AppTheme.burgundy,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHero = widget.tone == PremiumPathTone.hero;
    final style = _style;
    final emphasised = isHero || _isHovered;

    final borderColor = _isHovered
        ? AppTheme.gold
        : (isHero ? AppTheme.gold.withValues(alpha: 0.55) : AppTheme.border);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: emphasised ? 1.8 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: emphasised
                      ? AppTheme.gold.withValues(alpha: 0.16)
                      : AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: _isHovered ? 30 : (isHero ? 26 : 18),
                  offset: Offset(0, _isHovered ? 15 : 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: style.tileGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: style.tileGlow.withValues(alpha: 0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: style.tileIconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.title,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.chevronBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 18,
                    color: style.chevronColor,
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
