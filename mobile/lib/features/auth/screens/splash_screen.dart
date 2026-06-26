import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.12, 1, curve: Curves.easeOut),
    );

    _animationController.forward().then((_) => _navigateWhenReady());
  }

  Future<void> _navigateWhenReady() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.status == AuthStatus.checking) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return _navigateWhenReady();
    }

    final hasGuestPlan =
        auth.status == AuthStatus.unauthenticated &&
        await context.read<GuestOnboardingStorage>().hasGuestPlan();

    if (!mounted) return;
    context.go(
      auth.status == AuthStatus.authenticated || hasGuestPlan
          ? AppRouter.home
          : AppRouter.onboarding,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 560,
      safeAreaBottom: false,
      child: Stack(
        children: [
          const Positioned.fill(child: AuthWeddingBackground()),
          Center(
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WeddingRingsBadge(size: 112),
                    const SizedBox(height: 28),
                    const AuthBrandMark(),
                    const SizedBox(height: 18),
                    Text(
                      'خططي لزفافك بكل أناقة ووضوح',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 42),
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
