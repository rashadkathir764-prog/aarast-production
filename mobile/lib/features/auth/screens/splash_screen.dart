import 'dart:async';
import 'dart:ui' show lerpDouble;

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

/// The opening (2.01). The phone shows the name «اعّرست» on the night while
/// the app starts (D123); this page carries on from that same frame:
/// - the first open on this phone is the welcome: the name glides from the
///   centre to its place and grows, the fireworks come in behind it and the
///   line under it, 900ms, then on (D122);
/// - every later open keeps the launch frame as it is, and leaves the moment
///   the account is known, with no wait of its own.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _glide;
  late final Animation<double> _line;
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

    _glide = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _line = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );

    // The account becoming known is heard, not polled.
    _auth.addListener(_leaveWhenReady);
    if (_celebrate) {
      // Remembered as it starts: a sign-out or a notification that takes the
      // app elsewhere mid-play still counts as the welcome seen.
      unawaited(preferences?.markOpeningCelebrated());
      _animationController.forward().then((_) {
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

    if (!mounted || !_stillOpening()) return;
    context.go(
      status == AuthStatus.authenticated || hasGuestPlan
          ? AppRouter.home
          : AppRouter.welcome,
    );
  }

  /// The opening goes on only from itself. A notification tapped cold or a
  /// sign-out (the push bridge, the auth redirector) may have chosen the next
  /// page in the same frame, and that choice is not overridden.
  bool _stillOpening() =>
      GoRouter.of(context).routeInformationProvider.value.uri.path ==
      AppRouter.splash;

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
    // The page lays out between the system bars; the launch drew the name at
    // the whole screen's centre. That centre, said between the bars:
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    final safe = media.size.height - top - media.padding.bottom;
    final centreY = safe <= 0
        ? 0.0
        : (media.size.height / 2 - top) / safe * 2 - 1;
    if (!_celebrate) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: AarastScreenFrame(
          key: const ValueKey('opening-night'),
          backgroundColor: base,
          child: Align(
            alignment: Alignment(0, centreY),
            child: const JourneyLaunchMark(),
          ),
        ),
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
                child: AnimatedBuilder(
                  animation: _animationController,
                  // From the launch's centre to where the approved splash
                  // rests (0.42 between the bars), growing as it goes.
                  builder: (context, _) => Align(
                    alignment: Alignment(
                      0,
                      lerpDouble(centreY, 0.42, _glide.value)!,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        JourneyWordmark(
                          size: lerpDouble(
                            JourneyLaunchMark.size,
                            AarastV3Icon.hero,
                            _glide.value,
                          )!,
                          color: AarastV3Color.onPrimary,
                        ),
                        // The line takes no room until it comes, so the name
                        // starts at the launch's very centre.
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: _line.value,
                            child: Opacity(
                              opacity: _line.value,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: AarastV3Space.x3,
                                ),
                                child: Text(
                                  'عرسك من أول ريال إلى آخر دفعة',
                                  textAlign: TextAlign.center,
                                  style: JourneyType.of(
                                    JourneyType.lead,
                                    color: AarastV3Color.onPrimaryMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
