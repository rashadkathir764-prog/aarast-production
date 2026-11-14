import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../diagnostics/app_logger.dart';
import 'app_router.dart';

/// Preserves app-level back navigation when a forward transition used
/// [GoRouter.go] and therefore did not leave a Navigator page to pop.
class AarastBackButtonDispatcher extends RootBackButtonDispatcher {
  AarastBackButtonDispatcher(
    this.router, {
    bool Function(String planId)? keptOnPhone,
  }) : _keptOnPhone = keptOnPhone ?? _noPlanKeptOnPhone,
       _currentLocation = router.routeInformationProvider.value.uri.toString() {
    router.routerDelegate.addListener(_handleRouteChanged);
  }

  final GoRouter router;

  /// Whether a plan id names a plan kept on the phone, whose «الرئيسية» tab
  /// leads to /home (AuthActionGuard.isLocalGuestPlanId, given by the app).
  final bool Function(String planId) _keptOnPhone;
  static bool _noPlanKeptOnPhone(String planId) => false;

  /// How many steps back the app keeps, so a long walk between screens that
  /// are not tabs (provider to provider, say) stays bounded. Tabs never stack
  /// (see [_handleRouteChanged]); twenty is more than any real path.
  static const _historyLimit = 20;

  /// The tabs of the route-owned plan shell (WeddingPlanShell).
  static const _planTabs = {
    'dashboard',
    'money',
    'tasks',
    'guests',
    'providers',
  };

  final List<_ContextRouteEntry> _history = <_ContextRouteEntry>[];
  String _currentLocation;
  Listenable? _contextListenable;
  String? Function()? _readContextKey;
  String? Function()? _readWeddingPlanId;
  String? _currentContextKey;
  String? _currentWeddingPlanId;
  bool _restoringHistory = false;
  bool _discardCurrentOnNextRoute = false;
  bool _navigatorHandlesPop = false;

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;

    final target = _backTarget(consume: true);
    if (target == null) return false;
    _restoringHistory = true;
    router.go(target);
    return true;
  }

  /// RA-MO-311: the navigator's own word on back (a pushed page, an open
  /// sheet, a page that holds the press), handed over by the app in place
  /// of Flutter's default listener. An app that targets Android 16 is asked
  /// for back only while it says it has somewhere to go, and the navigator
  /// knows nothing of the places this dispatcher goes back to: a page
  /// reached by `go` has no page under it, so Android closed the app without
  /// asking. The system is told the two together.
  bool onNavigationNotification(NavigationNotification notification) {
    _navigatorHandlesPop = notification.canHandlePop;
    _tellSystemWhoHandlesBack();
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Nothing is said while the app is not attached; say it once it is.
    if (state == AppLifecycleState.resumed) _tellSystemWhoHandlesBack();
  }

  void _tellSystemWhoHandlesBack() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.detached) return;
    unawaited(
      SystemNavigator.setFrameworkHandlesBack(
        _navigatorHandlesPop || _backTarget(consume: false) != null,
      ),
    );
  }

  /// Where back leads when no page is left to pop: the last place of this
  /// context that can be reopened, else the page's parent. Null on a root,
  /// where back leaves the app. [consume] drops the history it passes, as a
  /// real press does; without it nothing changes.
  String? _backTarget({required bool consume}) {
    for (var index = _history.length - 1; index >= 0; index--) {
      final previous = _history[index];
      if (consume) _history.removeLast();
      if (previous.contextKey != _currentContextKey ||
          previous.location == _currentLocation ||
          !_restorableByLocation(previous.location) ||
          _homeAgain(previous.location)) {
        continue;
      }
      return previous.location;
    }

    var fallback = fallbackLocationFor(router.state.uri);
    if (_contextListenable != null && fallback != null) {
      final fallbackPlanId = _planIdFromLocation(fallback);
      if (fallbackPlanId != null && fallbackPlanId != _currentWeddingPlanId) {
        fallback = AppRouter.home;
      } else if (fallbackPlanId != null &&
          _currentContextKey?.endsWith(':contributor') == true &&
          Uri.parse(fallback).path.endsWith('/dashboard')) {
        fallback = AppRouter.home;
      }
    }
    if (fallback == null ||
        fallback == _currentLocation ||
        _homeAgain(fallback)) {
      return null;
    }
    return fallback;
  }

  void dispose() {
    _contextListenable?.removeListener(_handleContextChanged);
    router.routerDelegate.removeListener(_handleRouteChanged);
  }

  /// Binds route history to the selected account context. Any context change
  /// drops prior entries and suppresses recording the route that belonged to
  /// the context being left.
  void bindContext({
    required Listenable listenable,
    required String? Function() readContextKey,
    String? Function()? readWeddingPlanId,
  }) {
    if (identical(_contextListenable, listenable)) return;
    _contextListenable?.removeListener(_handleContextChanged);
    _contextListenable = listenable;
    _readContextKey = readContextKey;
    _readWeddingPlanId = readWeddingPlanId;
    _currentContextKey = readContextKey();
    _currentWeddingPlanId = readWeddingPlanId?.call();
    _history.clear();
    listenable.addListener(_handleContextChanged);
  }

  /// RA-MO-162: on the selected plan's home, `/home` is that same home (the
  /// entry opens it straight away), so back to it showed the home twice.
  bool _homeAgain(String target) {
    final planId = _currentWeddingPlanId;
    if (planId == null || Uri.tryParse(target)?.path != AppRouter.home) {
      return false;
    }
    return Uri.tryParse(_currentLocation)?.path ==
        AppRouter.weddingPlanDashboard(planId);
  }

  /// RA-MO-120: the code page lives on what it was opened with (its number,
  /// its purpose), not on its address; gone back to by the address alone it
  /// opened empty, and its check was refused with a general message.
  static bool _restorableByLocation(String location) =>
      Uri.tryParse(location)?.path != AppRouter.otp;

  /// The page [uri] belongs under: where back leads from a page opened by
  /// its address alone, and where the app returns in place of a one-time
  /// celebration (LastPlaceKeeper). Null on a root.
  static String? fallbackLocationFor(Uri uri) {
    final path = uri.path;
    if (_isNavigationRoot(path)) return null;

    if (path == AppRouter.login ||
        path == AppRouter.register ||
        path == AppRouter.otp ||
        path == AppRouter.onboarding) {
      return AppRouter.welcome;
    }
    // «نسيت كلمة المرور» goes back to signing in, as its own arrow does.
    if (path == AppRouter.resetPassword) return AppRouter.login;

    if (path == AppRouter.providerProfileEdit ||
        path == AppRouter.providerServiceNew ||
        path == AppRouter.providerPackageNew) {
      return AppRouter.providerDashboard;
    }
    if (path == AppRouter.favoriteProviders) {
      return AppRouter.providerMarketplace;
    }
    if (path == AppRouter.settings || path == AppRouter.support) {
      return AppRouter.more;
    }
    if (path == AppRouter.more ||
        path == AppRouter.notifications ||
        path == AppRouter.weddingPlans ||
        path == AppRouter.sharedWeddingPlans) {
      return AppRouter.home;
    }
    if (path == AppRouter.createWeddingPlan) {
      return AppRouter.weddingPlans;
    }

    final segments = uri.pathSegments;
    if (segments.length >= 3 && segments.first == 'providers') {
      final providerId = segments[1];
      if (segments.length >= 3 &&
          (segments[2] == 'quote' || segments[2] == 'quote-request')) {
        return AppRouter.providerDetails(providerId);
      }
      return AppRouter.providerMarketplace;
    }

    if (segments.length >= 3 &&
        segments[0] == 'wedding-plans' &&
        segments[1].isNotEmpty) {
      final planId = segments[1];
      final section = segments[2];
      if (section == 'dashboard') {
        return AppRouter.home;
      }
      if (section == 'tasks') {
        return segments.length > 3
            ? AppRouter.tasks(planId)
            : AppRouter.weddingPlanDashboard(planId);
      }
      if (section == 'guests') {
        return segments.length > 3
            ? AppRouter.guestList(planId)
            : AppRouter.weddingPlanDashboard(planId);
      }
      if (section == 'providers') {
        return AppRouter.weddingPlanDashboard(planId);
      }
      if (section == 'money') {
        return segments.length > 3
            ? AppRouter.money(planId)
            : AppRouter.weddingPlanDashboard(planId);
      }
      return AppRouter.weddingPlanDashboard(planId);
    }

    return AppRouter.home;
  }

  void _handleRouteChanged() {
    _noteRouteChange();
    _tellSystemWhoHandlesBack();
  }

  void _noteRouteChange() {
    final next = router.state.uri.toString();
    if (next == _currentLocation) return;
    appLogEvent(
      'NAVIGATION_EFFECTIVE_TRANSITION',
      category: AppLogCategory.navigation,
      activeContextKey: _currentContextKey,
      currentRoute: _currentLocation,
      targetRoute: next,
      reason: _restoringHistory ? 'history_restore' : 'router_transition',
      source: 'AarastBackButtonDispatcher',
    );

    if (_restoringHistory) {
      _restoringHistory = false;
      // Back that lands on a root has nothing left behind it, as when the
      // root is reached going forward.
      if (_isNavigationRoot(Uri.parse(next).path)) _history.clear();
      _currentLocation = next;
      return;
    }

    if (_discardCurrentOnNextRoute) {
      _discardCurrentOnNextRoute = false;
      _history.clear();
      _currentLocation = next;
      return;
    }

    if (_isNavigationRoot(Uri.parse(next).path)) {
      _history.clear();
      _currentLocation = next;
      return;
    }

    // RA-MO-13: a tab of the route-owned plan shell is a place, not a step.
    // Switching between two tabs of one plan stacks nothing; only the place
    // the plan's first tab leads to stays above where the plan was opened,
    // so back goes there and then out, however many taps were made (as the
    // in-route shells do, RootTabBackScope).
    final leavingPlan = _planOfTab(_currentLocation);
    final nextPlan = _planOfTab(next);
    if (leavingPlan != null && leavingPlan == nextPlan) {
      final first = _firstTabOf(nextPlan!);
      final firstOnTop =
          _history.isNotEmpty &&
          _history.last.contextKey == _currentContextKey &&
          _history.last.location == first;
      if (Uri.parse(next).path == first) {
        if (firstOnTop) _history.removeLast();
      } else if (!firstOnTop) {
        _history.add(
          _ContextRouteEntry(location: first, contextKey: _currentContextKey),
        );
      }
      _currentLocation = next;
      return;
    }

    if (_history.isNotEmpty &&
        _history.last.contextKey == _currentContextKey &&
        _history.last.location == next) {
      _history.removeLast();
    } else {
      _history.add(
        _ContextRouteEntry(
          location: _currentLocation,
          contextKey: _currentContextKey,
        ),
      );
      if (_history.length > _historyLimit) {
        _history.removeRange(0, _history.length - _historyLimit);
      }
    }
    _currentLocation = next;
  }

  void _handleContextChanged() {
    final nextContextKey = _readContextKey?.call();
    if (nextContextKey == _currentContextKey) return;
    appLogEvent(
      'NAVIGATION_RESET',
      category: AppLogCategory.navigation,
      fromContextKey: _currentContextKey,
      toContextKey: nextContextKey,
      currentRoute: _currentLocation,
      reason: 'active_context_changed',
      source: 'AarastBackButtonDispatcher',
    );
    _currentContextKey = nextContextKey;
    _currentWeddingPlanId = _readWeddingPlanId?.call();
    _history.clear();
    _restoringHistory = false;
    _discardCurrentOnNextRoute = true;
    _tellSystemWhoHandlesBack();
  }

  static bool _isNavigationRoot(String path) {
    return path == AppRouter.home ||
        path == AppRouter.providerDashboard ||
        path == AppRouter.welcome;
  }

  /// The plan whose shell tab [location] is (`/wedding-plans/<id>/<tab>`),
  /// else null. A step inside a tab (`/money/costs/create`) is not a tab.
  static String? _planOfTab(String location) {
    final segments = Uri.tryParse(location)?.pathSegments;
    if (segments == null ||
        segments.length != 3 ||
        segments.first != 'wedding-plans' ||
        segments[1].isEmpty ||
        !_planTabs.contains(segments[2])) {
      return null;
    }
    return segments[1];
  }

  /// Where the plan's «الرئيسية» tab leads (WeddingPlanShell._onNavigate):
  /// a plan kept on the phone has its one home at /home.
  String _firstTabOf(String planId) => _keptOnPhone(planId)
      ? AppRouter.home
      : AppRouter.weddingPlanDashboard(planId);

  static String? _planIdFromLocation(String location) {
    final segments = Uri.tryParse(location)?.pathSegments;
    if (segments == null ||
        segments.length < 2 ||
        segments.first != 'wedding-plans') {
      return null;
    }
    return segments[1];
  }
}

class _ContextRouteEntry {
  const _ContextRouteEntry({required this.location, required this.contextKey});

  final String location;
  final String? contextKey;
}
