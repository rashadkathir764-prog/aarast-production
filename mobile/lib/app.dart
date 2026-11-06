import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'core/diagnostics/app_logger.dart';
import 'core/experience_v3/aarast_v3.dart';
import 'core/preferences/device_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/routing/aarast_back_button_dispatcher.dart';
import 'core/push/push_lifecycle_bridge.dart';
import 'core/security/app_lock_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/aarast_loading_state.dart' show AarastInlineSpinner;
import 'core/widgets/aarast_toast.dart';
import 'features/account_contexts/account_contexts_api.dart'
    show
        AccountContext,
        AccountContextController,
        AccountContextPersona,
        AccountContextRole;
import 'features/auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
import 'features/onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, GuestPersona;
import 'features/settings/settings_api.dart' show DeletionPendingScreen;
import 'features/wedding_plans/wedding_plans_api.dart'
    show DashboardSummary, DashboardSummaryProvider;

class AarastApp extends StatefulWidget {
  const AarastApp({super.key});

  @override
  State<AarastApp> createState() => _AarastAppState();
}

class _AarastAppState extends State<AarastApp> {
  // Created once per app lifetime: rebuilding the root widget must never
  // recreate the router, or the whole navigation state would be lost.
  late final GoRouter _router = AppRouter.create();
  late final AarastBackButtonDispatcher _backButtonDispatcher =
      AarastBackButtonDispatcher(
        _router,
        keptOnPhone: AuthActionGuard.isLocalGuestPlanId,
      );

  /// D87: read when a notification is tapped, never as a dependency of the
  /// root builder (a rebuild of the whole app on every context change).
  static bool _providerAccount(BuildContext context) {
    try {
      return context
              .read<AccountContextController>()
              .selectedContext
              ?.isProvider ??
          false;
    } on ProviderNotFoundException {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final accountContexts = context.read<AccountContextController>();
      _backButtonDispatcher.bindContext(
        listenable: accountContexts,
        readContextKey: () => accountContexts.selectedContext?.contextKey,
        readWeddingPlanId: () => accountContexts.selectedContext?.weddingPlanId,
      );
    } on ProviderNotFoundException {
      // Isolated app-shell tests may omit account context wiring.
    }
  }

  @override
  void dispose() {
    _backButtonDispatcher.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return AarastBuildErrorBoundary(
      child: MaterialApp.router(
        title: 'اعّرست',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        routeInformationProvider: _router.routeInformationProvider,
        routeInformationParser: _router.routeInformationParser,
        routerDelegate: _router.routerDelegate,
        backButtonDispatcher: _backButtonDispatcher,
        builder: (context, child) {
          final auth = context.watch<AuthController>();
          // g02 «خط كبير»: every text a step bigger, on top of the phone's;
          // the two together stop at 1.3 (D30).
          final largeText =
              context.watch<DevicePreferences?>()?.largeText ?? false;
          final media = MediaQuery.of(context);
          final scaled = media.copyWith(
            textScaler: DevicePreferences.textScalerFor(
              media.textScaler,
              largeText: largeText,
            ),
          );
          final authenticatedUserId = auth.status == AuthStatus.authenticated
              ? auth.user?.id
              : null;
          return AarastPlanProfileScope(
            child: MediaQuery(
              data: scaled,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AarastPushLifecycleBridge(
                  router: _router,
                  authenticatedUserId: authenticatedUserId,
                  isProviderAccount: () => _providerAccount(context),
                  child: AarastV3AdaptiveExperienceShell(
                    routeListenable: _router.routeInformationProvider,
                    readLocation: () =>
                        _router.routeInformationProvider.value.uri.toString(),
                    child: AarastSessionTransitionGate(
                      child: AarastAuthFlowRedirector(
                        router: _router,
                        child: AppLockGate(
                          onForgotCode: auth.logout,
                          name: auth.user?.name,
                          child: AarastDeletionPendingGate(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The open plan's profile for the whole app (JOURNEY_PROFILE.md, B5).
///
/// The colours and the plan's words follow whose plan is open: the
/// selected plan, owned or helped in (q09 draws the groom's plan in his
/// teal for the bride who helps in it, q17 the bride's in her rose for her
/// sister), or the plan kept on the phone before an account. The words to
/// the reader follow the reader: in a plan the server resolved how it
/// speaks to them once (`readerForm`: the account's persona, else their
/// partner role, else the plan's side, D59), so the phone never decides it
/// again; outside a plan ([readerIsFeminine]) the account's own persona
/// ([accountPersona]), or a plan kept on the phone's own party. The
/// provider portal and the screens outside a plan take the app's teal,
/// still speaking to the reader as who they are.
@visibleForTesting
JourneyProfile planJourneyProfile({
  AccountContext? selected,
  DashboardSummary? summary,
  String? accountPersona,
  String? keptPlanPersona,
}) {
  final String? planPersona;
  if (selected != null) {
    planPersona = selected.role == AccountContextRole.provider
        ? null
        : switch (selected.persona) {
            AccountContextPersona.bride => 'BRIDE',
            AccountContextPersona.groom => 'GROOM',
            _ => null,
          };
  } else if (summary != null && summary.isLocalOnly) {
    planPersona = summary.persona;
  } else {
    // D75: no plan open, but one kept on this phone (saving it, its code,
    // moving it into the account): that plan's owner.
    planPersona = keptPlanPersona;
  }
  // A plan on the phone has no account yet: its owner is the plan's party.
  final reader = selected == null && summary != null && summary.isLocalOnly
      ? summary.persona
      : selected == null && keptPlanPersona != null
      ? keptPlanPersona
      : accountPersona;
  return JourneyProfile.of(
    planPersona: planPersona,
    readerFeminine:
        selected?.readerFeminine ??
        readerIsFeminine(accountPersona: reader, planPersona: planPersona),
    // D59: a participant reads the owner's money with the owner named.
    readerIsOwner: selected?.role != AccountContextRole.contributor,
  );
}

/// Provides [planJourneyProfile] above the router, so every page, sheet and
/// dialog reads the same profile.
@visibleForTesting
class AarastPlanProfileScope extends StatelessWidget {
  const AarastPlanProfileScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    AccountContext? selected;
    DashboardSummary? summary;
    try {
      selected = context.select<AccountContextController, AccountContext?>(
        (controller) => controller.selectedContext,
      );
    } on ProviderNotFoundException {
      selected = null;
    }
    try {
      summary = context.select<DashboardSummaryProvider, DashboardSummary?>(
        (provider) => provider.summary,
      );
    } on ProviderNotFoundException {
      summary = null;
    }
    String? accountPersona;
    try {
      accountPersona = context.select<AuthController, String?>(
        (auth) => auth.user?.persona,
      );
    } on ProviderNotFoundException {
      accountPersona = null;
    }
    // The kept plan's owner speaks only before there is an account (saving
    // the plan, its code); a signed-in session waits for its own plan, and
    // the move into the account sets its own profile.
    bool signedIn;
    try {
      signedIn = context.select<AuthController, bool>(
        (auth) => auth.status == AuthStatus.authenticated,
      );
    } on ProviderNotFoundException {
      signedIn = false;
    }
    ValueListenable<GuestPersona?>? kept;
    if (!signedIn) {
      try {
        kept = context.read<GuestOnboardingStorage>().keptPlanPersona;
      } on ProviderNotFoundException {
        kept = null;
      }
    }
    Widget scoped(GuestPersona? keptPersona) => JourneyProfileScope(
      profile: planJourneyProfile(
        selected: selected,
        summary: summary,
        accountPersona: accountPersona,
        keptPlanPersona: switch (keptPersona) {
          GuestPersona.bride => 'BRIDE',
          GuestPersona.groom => 'GROOM',
          _ => null,
        },
      ),
      child: child,
    );
    if (kept == null) return scoped(null);
    return ValueListenableBuilder<GuestPersona?>(
      valueListenable: kept,
      builder: (context, persona, _) => scoped(persona),
    );
  }
}

@visibleForTesting
class AarastSessionTransitionGate extends StatelessWidget {
  const AarastSessionTransitionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    AuthStatus status;
    try {
      status = context.select<AuthController, AuthStatus>(
        (controller) => controller.status,
      );
    } on ProviderNotFoundException {
      return child;
    }

    if (status == AuthStatus.checking) {
      return const _SessionWait(
        key: Key('session-checking-screen'),
        text: 'لحظة، نتأكد من دخولك…',
      );
    }

    if (status == AuthStatus.terminating) {
      return const _SessionWait(
        key: Key('session-terminating-screen'),
        text: 'لحظة، نطلّعك بأمان…',
      );
    }

    if (status == AuthStatus.terminationFailed) {
      final failure = context.select<AuthController, (String?, String?)>(
        (controller) => (controller.errorCode, controller.errorMessage),
      );
      return Scaffold(
        key: const Key('session-termination-failed-screen'),
        backgroundColor: AarastV3Color.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AarastV3Space.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const JourneyIconTile(
                    icon: LucideIcons.alertTriangle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                    size: 64,
                    radius: 20,
                  ),
                  const SizedBox(height: AarastV3Space.x4),
                  Text(
                    'ما قدرنا نطلّعك من هذا الجوال',
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.pageTitle,
                      weight: JourneyType.bold,
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    failure.$2 ??
                        'ما نعرض حساب قديم ولا شاشة الدخول قبل ما ننظّف بيانات هذا الجوال.',
                    key: const Key('session-termination-failure-message'),
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.body,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x5),
                  JourneyButton(
                    key: const Key('session-termination-retry'),
                    label: 'حاول مرة ثانية',
                    icon: LucideIcons.refreshCw,
                    large: true,
                    onPressed: () {
                      unawaited(context.read<AuthController>().logout());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}

/// D63 (w06, a01): an account waiting out its deletion sees only w06,
/// whether it just asked or signed in on any phone. It sits under the app
/// lock, so taking the request back needs the phone's code like anything else.
@visibleForTesting
class AarastDeletionPendingGate extends StatelessWidget {
  const AarastDeletionPendingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    bool pending;
    try {
      pending = context.select<AuthController, bool>(
        (controller) => controller.deletionPending,
      );
    } on ProviderNotFoundException {
      return child;
    }
    return pending ? const DeletionPendingScreen() : child;
  }
}

/// A short wait while the session is checked or closed: the kit's spinner
/// and one plain line.
class _SessionWait extends StatelessWidget {
  const _SessionWait({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AarastV3Color.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AarastV3Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AarastInlineSpinner(
                  dimension: 28,
                  color: AarastV3Color.primary,
                ),
                const SizedBox(height: AarastV3Space.x5),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
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

@visibleForTesting
class AarastBuildErrorBoundary extends StatefulWidget {
  const AarastBuildErrorBoundary({required this.child, super.key});

  final Widget child;

  @override
  State<AarastBuildErrorBoundary> createState() =>
      _AarastBuildErrorBoundaryState();
}

class _AarastBuildErrorBoundaryState extends State<AarastBuildErrorBoundary> {
  late final ErrorWidgetBuilder _previousBuilder;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (details) => const AarastBuildErrorScreen();
  }

  @override
  void dispose() {
    ErrorWidget.builder = _previousBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

@visibleForTesting
class AarastBuildErrorScreen extends StatelessWidget {
  const AarastBuildErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('app-build-error-boundary'),
      color: Colors.white,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AarastV3Space.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 52),
                const SizedBox(height: AarastV3Space.x4),
                const Text(
                  'تعذر بناء الصفحة',
                  style: TextStyle(
                    fontSize: JourneyType.pageTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x2),
                const Text(
                  'حدث خطأ غير متوقع في الواجهة. يمكنك العودة إلى اختيار المسار.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AarastV3Space.x5),
                OutlinedButton(
                  key: const Key('app-build-error-home-button'),
                  onPressed: () {
                    try {
                      GoRouter.of(context).go(AppRouter.home);
                    } on Object {
                      // The boundary can also render outside a router in
                      // isolated tests; keep the error visible in that case.
                    }
                  },
                  child: const Text('العودة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// x18 «ادخل مرة ثانية»: the sign-in after an expired session, with the
/// same number filled in and the page it was on to return to («بعد الدخول
/// ترجع مكانك»). Only a page inside the app is carried: never the doors
/// (welcome, sign-in, sign-up, the code) nor anything outside the app.
@visibleForTesting
String sessionExpiredLoginLocation({String? phone, String? from}) {
  return Uri(
    path: AppRouter.login,
    queryParameters: {
      'expired': '1',
      'phone': ?phone,
      'resume': ?_resumableLocation(from),
    },
  ).toString();
}

const _doorPaths = {
  AppRouter.splash,
  AppRouter.welcome,
  AppRouter.onboarding,
  AppRouter.login,
  AppRouter.register,
  AppRouter.resetPassword,
  AppRouter.otp,
};

String? _resumableLocation(String? location) {
  final value = location?.trim() ?? '';
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (_doorPaths.contains(uri.path)) return null;
  return value;
}

/// Handles navigation that must survive the account-scoped subtree being
/// recreated. In particular, a phone-verified private invite resumes only
/// after the new account boundary is mounted.
@visibleForTesting
class AarastAuthFlowRedirector extends StatefulWidget {
  const AarastAuthFlowRedirector({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<AarastAuthFlowRedirector> createState() =>
      _AarastAuthFlowRedirectorState();
}

class _AarastAuthFlowRedirectorState extends State<AarastAuthFlowRedirector> {
  AuthController? _auth;

  GoRouter get router => widget.router;
  Widget get child => widget.child;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      auth = null;
    }
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_noteExpiredSessionLocation);
    _auth = auth?..addListener(_noteExpiredSessionLocation);
  }

  @override
  void dispose() {
    _auth?.removeListener(_noteExpiredSessionLocation);
    super.dispose();
  }

  /// The moment a session expires, this router still shows the page it was
  /// on; the account's screens (and this router) are torn down right after,
  /// so the page is kept with the session's controller for x18.
  void _noteExpiredSessionLocation() {
    final auth = _auth;
    if (auth == null || !auth.sessionExpired) return;
    auth.noteExpiredSessionLocation(
      router.routeInformationProvider.value.uri.toString(),
    );
  }

  /// D75: a sign-up code for a number that already had an account signed
  /// in to it. Said once, where the person lands; a provider's joining says
  /// it on its own first step.
  void _announceFoundAccount(AuthController auth, String? location) {
    if (!auth.claimSignUpFoundAccountNotice()) return;
    if (location?.startsWith('/provider/') == true) return;
    final name = auth.signUpFoundAccountName;
    final message = name == null
        ? context.say(
            'هذا الرقم عليه حساب، دخلناك عليه.',
            'هذا الرقم عليه حساب، دخلناكِ عليه.',
          )
        : context.say(
            'هذا الرقم عليه حساب باسم $name، دخلناك عليه.',
            'هذا الرقم عليه حساب باسم $name، دخلناكِ عليه.',
          );
    // This widget sits above the router's navigator, so the toast takes
    // that navigator's overlay, as the push bridge does.
    AarastToast.showInfo(
      context,
      message,
      overlay: router.routerDelegate.navigatorKey.currentState?.overlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    ({
      bool sessionExpired,
      bool hasPendingInvite,
      bool loginRequestedAfterLogout,
      bool hasPendingAuthenticatedEntry,
    })
    flow;
    try {
      flow = context
          .select<
            AuthController,
            ({
              bool sessionExpired,
              bool hasPendingInvite,
              bool loginRequestedAfterLogout,
              bool hasPendingAuthenticatedEntry,
            })
          >(
            (controller) => (
              sessionExpired: controller.sessionExpired,
              hasPendingInvite: controller.hasPendingInviteResume,
              loginRequestedAfterLogout: controller.loginRequestedAfterLogout,
              hasPendingAuthenticatedEntry:
                  controller.hasPendingAuthenticatedEntry,
            ),
          );
    } on ProviderNotFoundException {
      return child;
    }

    if (flow.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<AuthController>().acknowledgeSessionExpiry();
        appLogEvent(
          'NAVIGATION_REQUEST',
          category: AppLogCategory.navigation,
          currentRoute: router.routeInformationProvider.value.uri.toString(),
          targetRoute: AppRouter.login,
          reason: 'session_expired',
          source: 'AarastAuthFlowRedirector',
        );
        final auth = context.read<AuthController>();
        // x18 «ادخل مرة ثانية», with the same number filled in and the
        // page it left to return to.
        router.go(
          sessionExpiredLoginLocation(
            phone: auth.expiredSessionPhone,
            from: auth.claimExpiredSessionLocation(),
          ),
        );
      });
    } else if (flow.loginRequestedAfterLogout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (context.read<AuthController>().claimLoginAfterLogout()) {
          appLogEvent(
            'NAVIGATION_REQUEST',
            category: AppLogCategory.navigation,
            currentRoute: router.routeInformationProvider.value.uri.toString(),
            targetRoute: AppRouter.login,
            reason: 'logout_completed',
            source: 'AarastAuthFlowRedirector',
          );
          router.go(AppRouter.login);
        }
      });
    } else if (flow.hasPendingInvite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final auth = context.read<AuthController>();
        final token = auth.claimPendingInviteResumeRoute();
        if (token != null) {
          final target = AppRouter.inviteDecision(token);
          appLogEvent(
            'NAVIGATION_REQUEST',
            category: AppLogCategory.navigation,
            currentRoute: router.routeInformationProvider.value.uri.toString(),
            targetRoute: target,
            reason: 'invite_resume',
            source: 'AarastAuthFlowRedirector',
          );
          router.go(target);
          _announceFoundAccount(auth, target);
        }
      });
    } else if (flow.hasPendingAuthenticatedEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final auth = context.read<AuthController>();
        if (!auth.hasPendingAuthenticatedEntry) return;
        final location = auth.claimPendingAuthenticatedEntry();
        final target = AppRouter.authenticatedEntry(location);
        appLogEvent(
          'NAVIGATION_REQUEST',
          category: AppLogCategory.navigation,
          currentRoute: router.routeInformationProvider.value.uri.toString(),
          targetRoute: target,
          reason: 'authenticated_entry',
          source: 'AarastAuthFlowRedirector',
        );
        router.go(target);
        _announceFoundAccount(auth, location);
      });
    }

    return child;
  }
}
