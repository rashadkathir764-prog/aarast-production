import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/routing/aarast_back_button_dispatcher.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_controller.dart';

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

    return MaterialApp.router(
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AarastAuthFlowRedirector(
            router: _router,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
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
    ({bool sessionExpired, bool hasPendingInvite}) flow;
    try {
      flow = context
          .select<
            AuthController,
            ({bool sessionExpired, bool hasPendingInvite})
          >(
            (controller) => (
              sessionExpired: controller.sessionExpired,
              hasPendingInvite: controller.hasPendingInviteResume,
            ),
          );
    } on ProviderNotFoundException {
      return child;
    }

    if (flow.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<AuthController>().acknowledgeSessionExpiry();
        router.go(AppRouter.login);
      });
    } else if (flow.hasPendingInvite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final token = context
            .read<AuthController>()
            .claimPendingInviteResumeRoute();
        if (token != null) router.go(AppRouter.inviteDecision(token));
      });
    }

    return child;
  }
}
