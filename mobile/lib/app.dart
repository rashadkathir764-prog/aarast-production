import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'core/diagnostics/app_logger.dart';
import 'core/experience_v3/aarast_v3.dart';
import 'core/routing/app_router.dart';
import 'core/routing/aarast_back_button_dispatcher.dart';
import 'core/push/push_lifecycle_bridge.dart';
import 'core/security/app_lock_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/account_contexts/account_contexts_api.dart'
    show AccountContextController;
import 'features/auth/auth_api.dart' show AuthController, AuthStatus;

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
      AarastBackButtonDispatcher(_router);

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
        title: 'أعرست',
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
          final authenticatedUserId = auth.status == AuthStatus.authenticated
              ? auth.user?.id
              : null;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AarastPushLifecycleBridge(
              router: _router,
              authenticatedUserId: authenticatedUserId,
              child: AarastV3AdaptiveExperienceShell(
                routeListenable: _router.routeInformationProvider,
                readLocation: () =>
                    _router.routeInformationProvider.value.uri.toString(),
                child: AarastSessionTransitionGate(
                  child: AarastAuthFlowRedirector(
                    router: _router,
                    child: AppLockGate(
                      onForgotCode: auth.logout,
                      child: child ?? const SizedBox.shrink(),
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
      return const Scaffold(
        key: Key('session-checking-screen'),
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'جارٍ التحقق من الجلسة…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (status == AuthStatus.terminating) {
      return const Scaffold(
        key: Key('session-terminating-screen'),
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'جارٍ إنهاء الجلسة بأمان…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (status == AuthStatus.terminationFailed) {
      final failure = context.select<AuthController, (String?, String?)>(
        (controller) => (controller.errorCode, controller.errorMessage),
      );
      final deletionPending = failure.$1 == 'ACCOUNT_DELETION_PENDING';
      return Scaffold(
        key: const Key('session-termination-failed-screen'),
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    color: AppTheme.danger,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    deletionPending
                        ? 'جارٍ التحقق من حذف الحساب'
                        : 'تعذر إنهاء الجلسة محلياً',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failure.$2 ??
                        'لن نعرض حساباً قديماً أو شاشة الدخول قبل اكتمال تنظيف بيانات هذا الجهاز.',
                    key: const Key('session-termination-failure-message'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('session-termination-retry'),
                    onPressed: () {
                      unawaited(context.read<AuthController>().logout());
                    },
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('إعادة المحاولة'),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'تعذر بناء الصفحة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدث خطأ غير متوقع في الواجهة. يمكنك العودة إلى اختيار المسار.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
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

/// Handles navigation that must survive the account-scoped subtree being
/// recreated. In particular, a phone-verified private invite resumes only
/// after the new account boundary is mounted.
@visibleForTesting
class AarastAuthFlowRedirector extends StatelessWidget {
  const AarastAuthFlowRedirector({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

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
        router.go(AppRouter.login);
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
        final token = context
            .read<AuthController>()
            .claimPendingInviteResumeRoute();
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
      });
    }

    return child;
  }
}
