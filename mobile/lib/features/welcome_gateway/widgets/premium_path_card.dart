import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

/// نغمة بطاقة المسار — تمنح كل مسار لبنة أيقونة متناسقة مع هوية أعرست.
/// [hero] و [gold] لبنتان مصمتتان بنفس الحضور (المساران الأساسيان)، و [quiet]
/// لبنة محدّدة بإطار: هدوءها مقصود لأنها فئة مختلفة، لا نسخة أضعف.
enum PremiumPathTone { hero, gold, quiet }

/// بطاقة واحدة تخدم دورين: بطاقة تنقّل ([selected] = null فتُذيّل بشيفرون)،
/// وبطاقة اختيار ([selected] غير null فتُذيّل بعلامة تحديد أو حلقة فارغة).
/// توحيدها يمنع تفاوت الفخامة بين خطوة المسار وخطوة الدور.
class PremiumPathCard extends StatefulWidget {
  const PremiumPathCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = PremiumPathTone.gold,
    this.selected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final PremiumPathTone tone;
  final bool? selected;

  @override
  State<PremiumPathCard> createState() => _PremiumPathCardState();
}

class _PathStyle {
  const _PathStyle({
    required this.tileIconColor,
    this.tileGradient,
    this.tileColor,
    this.tileBorder,
    this.tileGlow,
  });

  final Color tileIconColor;
  final Gradient? tileGradient;
  final Color? tileColor;
  final Color? tileBorder;
  final Color? tileGlow;
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
        );
      case PremiumPathTone.quiet:
        return const _PathStyle(
          tileColor: AppTheme.empty,
          tileBorder: AppTheme.border,
          tileIconColor: AppTheme.burgundy,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected ?? false;
    final isHero = widget.tone == PremiumPathTone.hero;
    final style = _style;
    final emphasised = isSelected || isHero || _isHovered;

    final borderColor = (isSelected || _isHovered)
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
              color: isSelected ? AppTheme.goldSoft : AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2.0 : (emphasised ? 1.8 : 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: emphasised
                      ? AppTheme.gold.withValues(alpha: 0.16)
                      : AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: _isHovered ? 30 : (emphasised ? 26 : 18),
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
                    color: style.tileColor,
                    borderRadius: BorderRadius.circular(18),
                    border: style.tileBorder == null
                        ? null
                        : Border.all(color: style.tileBorder!, width: 1.5),
                    boxShadow: style.tileGlow == null
                        ? null
                        : [
                            BoxShadow(
                              color: style.tileGlow!.withValues(alpha: 0.32),
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
                _PathTrailing(selected: widget.selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ذيل البطاقة: شيفرون عارٍ للتنقّل (نفس لغة بقية التطبيق)، وعلامة تحديد
/// أو حلقة فارغة للاختيار.
class _PathTrailing extends StatelessWidget {
  const _PathTrailing({required this.selected});

  final bool? selected;

  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return const Icon(
        LucideIcons.chevronLeft,
        size: 20,
        color: AppTheme.disabled,
      );
    }
    if (selected!) {
      return const Icon(
        LucideIcons.checkCircle,
        size: 24,
        color: AppTheme.burgundy,
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
    );
  }
}
