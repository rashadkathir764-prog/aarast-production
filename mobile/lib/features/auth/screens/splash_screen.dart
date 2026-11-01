import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../providers/auth_controller.dart';

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
      duration: const Duration(milliseconds: 900),
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
    if (auth.status == AuthStatus.terminating ||
        auth.status == AuthStatus.terminationFailed) {
      return;
    }

    final hasGuestPlan =
        auth.status == AuthStatus.unauthenticated &&
        await context.read<GuestOnboardingStorage>().hasGuestPlan();

    if (!mounted) return;
    context.go(
      auth.status == AuthStatus.authenticated || hasGuestPlan
          ? AppRouter.home
          : AppRouter.welcome,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // a01: the wedding sky, the name, and what the app is for. The status
    // bar reads light over the night. a01 is the same for every journey, so
    // it keeps the app's own sky whatever plan opens next.
    final night = JourneyAccent.groom.night;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AarastScreenFrame(
        maxWidth: 560,
        backgroundColor: night,
        backgroundDecoration: BoxDecoration(color: night),
        child: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const JourneyWeddingSky(base: AarastV3Color.primaryDark),
              Align(
                alignment: const Alignment(0, 0.42),
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const JourneyWordmark(
                          size: 64,
                          color: AarastV3Color.onPrimary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'عرسك من أول ريال إلى آخر دفعة',
                          textAlign: TextAlign.center,
                          style: JourneyType.of(
                            JourneyType.bodyLarge,
                            color: AarastV3Color.onPrimaryMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
