import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../providers/auth_controller.dart';

/// The opening (2.01). The phone shows the night with «ع» while the app
/// starts; this page carries on from that same night (2026-11-23):
/// - the first open on this phone is the welcome: the fireworks and the name,
///   900ms, then on;
/// - every later open is the night alone, and leaves the moment the account
///   is known, with no wait of its own, as world apps open straight in.
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
  late final AuthController _auth;

  /// The fireworks play on this open. No preferences (a preview) is a first
  /// open.
  late final bool _celebrate;
  bool _openingDone = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    final preferences = context.read<DevicePreferences?>();
    _celebrate = !(preferences?.openingCelebrated ?? false);
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

    // The account becoming known is heard, not polled.
    _auth.addListener(_leaveWhenReady);
    if (_celebrate) {
      _animationController.forward().then((_) {
        unawaited(preferences?.markOpeningCelebrated());
        _openingDone = true;
        _leaveWhenReady();
      });
    } else {
      _openingDone = true;
      // Going on needs the router, which is there from the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveWhenReady());
    }
  }

  Future<void> _leaveWhenReady() async {
    if (!mounted || _left || !_openingDone) return;
    final status = _auth.status;
    if (status == AuthStatus.checking) return;
    // A sign-out under way is taken on by its own gate, not this page.
    if (status == AuthStatus.terminating ||
        status == AuthStatus.terminationFailed) {
      _left = true;
      return;
    }
    _left = true;

    final hasGuestPlan =
        status == AuthStatus.unauthenticated &&
        await context.read<GuestOnboardingStorage>().hasGuestPlan();

    if (!mounted) return;
    context.go(
      status == AuthStatus.authenticated || hasGuestPlan
          ? AppRouter.home
          : AppRouter.welcome,
    );
  }

  @override
  void dispose() {
    _auth.removeListener(_leaveWhenReady);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The night the phone opened on: the sky's own colour, and the one the
    // fireworks melt into.
    final base = JourneyAccent.groom.night;
    if (!_celebrate) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ColoredBox(key: const ValueKey('opening-night'), color: base),
      );
    }
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
