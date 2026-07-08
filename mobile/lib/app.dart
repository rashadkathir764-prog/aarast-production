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
          child: _SessionExpiryRedirector(
            router: _router,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Watches for a mid-session 401 (session invalidated server-side) and
/// redirects to the login screen exactly once, so the user gets a clean
/// re-login path instead of stale screens full of errors.
class _SessionExpiryRedirector extends StatelessWidget {
  const _SessionExpiryRedirector({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    bool expired;
    try {
      expired = context.select<AuthController, bool>(
        (controller) => controller.sessionExpired,
      );
    } on ProviderNotFoundException {
      return child;
    }

    if (expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<AuthController>().acknowledgeSessionExpiry();
        router.go(AppRouter.login);
      });
    }

    return child;
  }
}
