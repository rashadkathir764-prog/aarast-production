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
    // Only the photo's upper half supplies the fireworks. Keep their natural
    // colours, and merge the sky into the kit's existing quiet night colour.
    final base = JourneyAccent.groom.night;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: base,
        child: Stack(
          fit: StackFit.expand,
          children: [
            JourneyCelebrationSky(base: base),
            AarastScreenFrame(
              backgroundColor: Colors.transparent,
              backgroundDecoration: const BoxDecoration(),
              child: JourneyProfileScope(
                profile: JourneyProfile.groom,
                child: Align(
                  alignment: const Alignment(0, 0.42),
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const JourneyWordmark(
                            size: AarastV3Icon.hero,
                            color: AarastV3Color.onPrimary,
                          ),
                          const SizedBox(height: AarastV3Space.x3),
                          Text(
                            'عرسك من أول ريال إلى آخر دفعة',
                            textAlign: TextAlign.center,
                            style: JourneyType.of(
                              JourneyType.lead,
                              color: AarastV3Color.onPrimaryMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
