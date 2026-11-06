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

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;

    while (_history.isNotEmpty) {
      final previous = _history.removeLast();
      if (previous.contextKey != _currentContextKey ||
          previous.location == _currentLocation) {
        continue;
      }
      _restoringHistory = true;
      router.go(previous.location);
      return true;
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
    if (fallback == null || fallback == _currentLocation) return false;

    _restoringHistory = true;
    router.go(fallback);
    return true;
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

  @visibleForTesting
  static String? fallbackLocationFor(Uri uri) {
    final path = uri.path;
    if (_isNavigationRoot(path)) return null;

    if (path == AppRouter.login ||
        path == AppRouter.register ||
        path == AppRouter.otp ||
        path == AppRouter.onboarding) {
      return AppRouter.welcome;
    }

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
