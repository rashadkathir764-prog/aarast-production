import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'aarast_design_tokens.dart';

class AarastMotion {
  const AarastMotion._();

  static bool reduceMotion(BuildContext context) {
    final data = MediaQuery.maybeOf(context);
    return data?.disableAnimations ?? false;
  }

  static Duration duration(BuildContext context, Duration value) {
    return reduceMotion(context) ? Duration.zero : value;
  }
}

/// One restrained transition language for all routed mobile screens.
///
/// It uses a short RTL-aware translation and opacity only. There is no scale
/// spectacle, glow, or delayed content reveal. Reduced-motion users receive
/// the destination immediately.
class AarastPageTransitionsBuilder extends PageTransitionsBuilder {
  const AarastPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || AarastMotion.reduceMotion(context)) return child;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final position = Tween<Offset>(
      begin: Offset(isRtl ? -0.035 : 0.035, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    final opacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.78, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: position, child: child),
    );
  }
}

/// Animates live data replacement without making the layout jump.
class AarastMotionSwitcher extends StatelessWidget {
  const AarastMotionSwitcher({
    required this.child,
    this.duration = AarastDesignTokens.motionStandard,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AarastMotion.duration(context, duration),
      reverseDuration: AarastMotion.duration(
        context,
        AarastDesignTokens.motionQuick,
      ),
      switchInCurve: AarastDesignTokens.motionCurve,
      switchOutCurve: AarastDesignTokens.motionExitCurve,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}

/// الدخول المتدرج الموحّد — نفس لغة الحركة في V3:
/// كل عنصر يطفو للأعلى بفارق نَفَس قصير مع fade ناعم.
/// كل الشاشات تستخدم هذا الحرس الواحد — لا نسخ محلية للـ stagger.
class AarastStagger {
  const AarastStagger._();

  static const _step = Duration(milliseconds: 32);
  static const _entry = AarastDesignTokens.motionStandard;

  /// يلفّ عنصراً واحداً بترتيبه [index] ضمن القائمة.
  /// التأخير مسقوف عند 8 خطوات حتى لا تتأخر عناصر القوائم الطويلة
  /// المبنية كسولاً أثناء التمرير.
  static Widget item(BuildContext context, Widget child, int index) {
    if (AarastMotion.reduceMotion(context) || child is SizedBox) return child;
    final delay = _step * index.clamp(0, 4);
    return child
        .animate()
        .fadeIn(delay: delay, duration: _entry, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.06,
          end: 0,
          delay: delay,
          duration: _entry,
          curve: Curves.easeOutCubic,
        );
  }

  /// يلفّ قائمة أطفال كاملة — جاهزة لـ ListView/Column مباشرة.
  static List<Widget> children(BuildContext context, List<Widget> items) {
    return [for (var i = 0; i < items.length; i++) item(context, items[i], i)];
  }
}

class AarastFadeSlide extends StatelessWidget {
  const AarastFadeSlide({
    required this.child,
    this.offset = const Offset(0, 16),
    this.duration = AarastDesignTokens.motionStandard,
    this.curve = AarastDesignTokens.motionCurve,
    super.key,
  });

  final Widget child;
  final Offset offset;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (AarastMotion.reduceMotion(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offset.dx * (1 - value), offset.dy * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class AarastStaggeredEntry extends StatelessWidget {
  const AarastStaggeredEntry({
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 40),
    this.duration = AarastDesignTokens.motionStandard,
    super.key,
  });

  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (AarastMotion.reduceMotion(context)) return child;

    final delay = Duration(
      milliseconds: baseDelay.inMilliseconds * index.clamp(0, 4),
    );
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: AarastDesignTokens.motionCurve)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: duration,
          curve: AarastDesignTokens.motionCurve,
        );
  }
}

class AarastSkeletonPulse extends StatelessWidget {
  const AarastSkeletonPulse({
    required this.child,
    this.lowOpacity = 0.38,
    this.highOpacity = 0.78,
    super.key,
  });

  final Widget child;
  final double lowOpacity;
  final double highOpacity;

  @override
  Widget build(BuildContext context) {
    if (AarastMotion.reduceMotion(context)) {
      return Opacity(opacity: highOpacity, child: child);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: lowOpacity, end: highOpacity),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, animatedChild) {
        return Opacity(opacity: value, child: animatedChild);
      },
      child: child,
    );
  }
}
