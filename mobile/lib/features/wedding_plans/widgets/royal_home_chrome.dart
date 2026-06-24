import 'dart:ui';

import 'package:flutter/material.dart';

class RoyalHomeAction {
  const RoyalHomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

Future<void> showRoyalHomeActionSheet(
  BuildContext context, {
  required List<RoyalHomeAction> actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      void close() => Navigator.of(dialogContext).pop();

      return Directionality(
        textDirection: TextDirection.rtl,
        child: _RoyalActionDialog(actions: actions, onClose: close),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return _RoyalActionTransition(animation: curved, child: child);
    },
  );
}

class RoyalDashboardBottomNav extends StatelessWidget {
  const RoyalDashboardBottomNav({
    required this.activeIndex,
    this.onHome,
    this.onMoney,
    this.onTasks,
    this.onGuests,
    this.onProviders,
    this.onMore,
    this.onAdd,
    super.key,
  });

  final int activeIndex;
  final VoidCallback? onHome;
  final VoidCallback? onMoney;
  final VoidCallback? onTasks;
  final VoidCallback? onGuests;
  final VoidCallback? onProviders;
  final VoidCallback? onMore;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = 86.0 + bottomInset;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 132 + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: navHeight - 12,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _RoyalHomeColors.ivory,
                        _RoyalHomeColors.ivory.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: navHeight,
              child: Container(
                padding: EdgeInsets.only(
                  top: 14,
                  left: 14,
                  right: 14,
                  bottom: bottomInset,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: _RoyalHomeColors.ink.withValues(alpha: 0.05),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _RoyalHomeColors.burgundy.withValues(alpha: 0.07),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoyalNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'الرئيسية',
                      active: activeIndex == 0,
                      onTap: onHome,
                    ),
                    _RoyalNavItem(
                      icon: Icons.credit_card_outlined,
                      activeIcon: Icons.credit_card_rounded,
                      label: 'المال',
                      active: activeIndex == 1,
                      onTap: onMoney,
                    ),
                    _RoyalNavItem(
                      icon: Icons.check_box_outlined,
                      activeIcon: Icons.check_box_rounded,
                      label: 'المهام',
                      active: activeIndex == 2,
                      onTap: onTasks,
                    ),
                    _RoyalNavItem(
                      icon: Icons.group_outlined,
                      activeIcon: Icons.group_rounded,
                      label: 'الضيوف',
                      active: activeIndex == 3,
                      onTap: onGuests,
                    ),
                    _RoyalNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'الموردون',
                      active: activeIndex == 4,
                      onTap: onProviders,
                    ),
                    _RoyalNavItem(
                      icon: Icons.more_horiz_rounded,
                      activeIcon: Icons.more_horiz_rounded,
                      label: 'المزيد',
                      active: activeIndex == 5,
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: navHeight + 10,
              child: _PressScale(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        _RoyalHomeColors.gold,
                        _RoyalHomeColors.goldDeep,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _RoyalHomeColors.gold.withValues(alpha: 0.36),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'إجراء جديد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoyalHomeActionSheet extends StatelessWidget {
  const RoyalHomeActionSheet({
    required this.actions,
    required this.onClose,
    super.key,
  });

  final List<RoyalHomeAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _RoyalHomeColors.ivory,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoyalSheetHeader(onClose: onClose),
              const SizedBox(height: 24),
              for (var i = 0; i < actions.length; i++) ...[
                _StaggeredSheetAction(index: i, action: actions[i]),
                if (i != actions.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoyalActionTransition extends StatelessWidget {
  const _RoyalActionTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(opacity: animation.value, child: child);
      },
      child: child,
    );
  }
}

class _RoyalActionDialog extends StatelessWidget {
  const _RoyalActionDialog({required this.actions, required this.onClose});

  final List<RoyalHomeAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    final animation = routeAnimation ?? kAlwaysCompleteAnimation;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                color: _RoyalHomeColors.ink.withValues(alpha: 0.50),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: RoyalHomeActionSheet(actions: actions, onClose: onClose),
          ),
        ),
      ],
    );
  }
}

class _RoyalSheetHeader extends StatelessWidget {
  const _RoyalSheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _RoyalHomeColors.burgundy.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            child: Text(
              'إجراء جديد',
              style: TextStyle(
                color: _RoyalHomeColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            bottom: 0,
            child: _PressScale(
              onTap: onClose,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _RoyalHomeColors.burgundy.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _RoyalHomeColors.burgundy,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredSheetAction extends StatelessWidget {
  const _StaggeredSheetAction({required this.index, required this.action});

  final int index;
  final RoyalHomeAction action;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 330 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: _RoyalActionTile(action: action),
    );
  }
}

class _RoyalActionTile extends StatelessWidget {
  const _RoyalActionTile({required this.action});

  final RoyalHomeAction action;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _RoyalHomeColors.gold.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(action.icon, color: _RoyalHomeColors.gold, size: 25),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RoyalHomeColors.burgundy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoyalNavItem extends StatelessWidget {
  const _RoyalNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _RoyalHomeColors.burgundy : _RoyalHomeColors.muted;

    return _PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 58,
        height: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 25),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _RoyalHomeColors {
  const _RoyalHomeColors._();

  static const ivory = Color(0xFFFDFBF9);
  static const burgundy = Color(0xFF800020);
  static const gold = Color(0xFFD4AF37);
  static const goldDeep = Color(0xFFB5952F);
  static const ink = Color(0xFF2D1A1E);
  static const muted = Color(0xFF8A7B7E);
}
