import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumRoleCard extends StatefulWidget {
  const PremiumRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<PremiumRoleCard> createState() => _PremiumRoleCardState();
}

class _PremiumRoleCardState extends State<PremiumRoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected ? AppTheme.goldSoft : AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.gold
                    : (_isHovered
                          ? AppTheme.gold.withValues(alpha: 0.5)
                          : AppTheme.border),
                width: widget.isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected || _isHovered
                      ? AppTheme.gold.withValues(alpha: 0.15)
                      : AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: widget.isSelected || _isHovered ? 20 : 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.surface
                        : AppTheme.empty,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: widget.isSelected
                          ? AppTheme.gold.withValues(alpha: 0.3)
                          : AppTheme.border,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isSelected
                        ? AppTheme.burgundy
                        : AppTheme.muted,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.title,
                              fontWeight: widget.isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              fontSize: 17,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.burgundy,
                    size: 24,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppTheme.disabled,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
