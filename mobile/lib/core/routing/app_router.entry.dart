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
    builder: (context, state) => LoginScreen(
      initialPhone: state.uri.queryParameters['phone'],
      sessionExpired: state.uri.queryParameters['expired'] == '1',
    ),
  ),
  GoRoute(
    path: AppRouter.register,
    builder: (context, state) {
      final query = state.uri.queryParameters;
      final resume = query['resume'];
      // p01 is the provider's own account. A return from the code screen
      // keeps only the resume, so a provider page there means a provider.
      final provider =
          query['type'] == 'provider' ||
          (resume != null &&
              !resume.startsWith('//') &&
              Uri.tryParse(resume)?.pathSegments.firstOrNull == 'provider');
      return provider
          ? ProviderRegisterScreen(
              initialPhone: query['phone'],
              resumeLocation: resume,
            )
          : RegisterScreen(initialPhone: query['phone']);
    },
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
