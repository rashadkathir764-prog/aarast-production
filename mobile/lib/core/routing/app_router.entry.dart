part of 'app_router.dart';

// Entry, onboarding and authentication, then the home entry.
List<RouteBase> _entryRoutes(AppFeatureFlags flags) => [
  GoRoute(
    path: AppRouter.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRouter.welcome,
    builder: (context, state) => const SmartWelcomeScreen(),
  ),
  // The smart welcome gateway is the single onboarding truth. Legacy
  // paths stay registered so old deep links keep working.
  GoRoute(
    path: AppRouter.onboarding,
    redirect: (context, state) => AppRouter.welcome,
    builder: (context, state) => const SmartWelcomeScreen(),
  ),
  GoRoute(
    path: AppRouter.guestOnboardingPreview,
    redirect: (context, state) => AppRouter.guestOnboardingRedirect(flags),
    builder: (context, state) => const SmartWelcomeScreen(),
  ),
  GoRoute(
    path: AppRouter.login,
    builder: (context, state) =>
        LoginScreen(initialPhone: state.uri.queryParameters['phone']),
  ),
  GoRoute(
    path: AppRouter.register,
    builder: (context, state) => RegisterScreen(
      startAsProvider: state.uri.queryParameters['type'] == 'provider',
      initialPhone: state.uri.queryParameters['phone'],
    ),
  ),
  GoRoute(
    path: AppRouter.resetPassword,
    builder: (context, state) =>
        ResetPasswordScreen(initialPhone: state.uri.queryParameters['phone']),
  ),
  GoRoute(
    path: AppRouter.otp,
    builder: (context, state) {
      final args = state.extra is OtpScreenArgs
          ? state.extra! as OtpScreenArgs
          : null;
      return OtpScreen(
        phone: args?.phone,
        purpose: args?.purpose,
        otpNoticeMessage: args?.otpNoticeMessage,
        registration: args?.registration,
        successLocation: args?.successLocation,
      );
    },
  ),
  GoRoute(
    path: AppRouter.home,
    builder: (context, state) => const DashboardEntryScreen(),
  ),
];
