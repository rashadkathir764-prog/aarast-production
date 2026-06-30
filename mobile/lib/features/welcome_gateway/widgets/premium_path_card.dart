import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumPathCard extends StatefulWidget {
  const PremiumPathCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<PremiumPathCard> createState() => _PremiumPathCardState();
}

class _PremiumPathCardState extends State<PremiumPathCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark Premium Theme
    final bgColor = widget.isPrimary 
        ? Colors.black.withValues(alpha: 0.3) 
        : Colors.white.withValues(alpha: 0.03);
        
    final borderColor = widget.isPrimary 
        ? AppTheme.dGoldDeep.withValues(alpha: 0.5) 
        : Colors.white.withValues(alpha: 0.1);
        
    final titleColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.7);
    
    final iconBgColor = widget.isPrimary 
        ? AppTheme.dGoldDeep.withValues(alpha: 0.15) 
        : Colors.white.withValues(alpha: 0.05);
        
    final iconColor = widget.isPrimary ? AppTheme.dGoldDeep : Colors.white;

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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isHovered ? AppTheme.dGoldDeep : borderColor,
                width: _isHovered ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isPrimary || _isHovered 
                      ? AppTheme.dGoldDeep.withValues(alpha: 0.15) 
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: _isHovered ? 30 : 20,
                  offset: Offset(0, _isHovered ? 15 : 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(widget.icon, color: iconColor, size: 30),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.isPrimary 
                        ? AppTheme.dGoldDeep.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded, 
                    size: 16, 
                    color: widget.isPrimary ? AppTheme.dGoldDeep : Colors.white,
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
