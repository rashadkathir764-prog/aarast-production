import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Preserves app-level back navigation when a forward transition used
/// [GoRouter.go] and therefore did not leave a Navigator page to pop.
class AarastBackButtonDispatcher extends RootBackButtonDispatcher {
  AarastBackButtonDispatcher(this.router)
    : _currentLocation = router.routeInformationProvider.value.uri.toString() {
    router.routerDelegate.addListener(_handleRouteChanged);
  }

  final GoRouter router;
  final List<String> _history = <String>[];
  String _currentLocation;
  bool _restoringHistory = false;

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;

    while (_history.isNotEmpty) {
      final previous = _history.removeLast();
      if (previous == _currentLocation) continue;
      _restoringHistory = true;
      router.go(previous);
      return true;
    }

    final fallback = fallbackLocationFor(router.state.uri);
    if (fallback == null || fallback == _currentLocation) return false;

    _restoringHistory = true;
    router.go(fallback);
    return true;
  }

  void dispose() {
    router.routerDelegate.removeListener(_handleRouteChanged);
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

    if (path == AppRouter.providerApplyStatus) {
      return AppRouter.providerApply;
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
      if (section == 'finance' || section == 'dashboard') {
        return section == 'dashboard'
            ? AppRouter.home
            : AppRouter.weddingPlanDashboard(planId);
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
      if (section == 'expenses' ||
          section == 'budget' ||
          section == 'budget-categories' ||
          section == 'debts') {
        return AppRouter.finance(planId);
      }
      return AppRouter.weddingPlanDashboard(planId);
    }

    return AppRouter.home;
  }

  void _handleRouteChanged() {
    final next = router.state.uri.toString();
    if (next == _currentLocation) return;

    if (_restoringHistory) {
      _restoringHistory = false;
      _currentLocation = next;
      return;
    }

    if (_isNavigationRoot(Uri.parse(next).path)) {
      _history.clear();
      _currentLocation = next;
      return;
    }

    if (_history.isNotEmpty && _history.last == next) {
      _history.removeLast();
    } else {
      _history.add(_currentLocation);
    }
    _currentLocation = next;
  }

  static bool _isNavigationRoot(String path) {
    return path == AppRouter.home ||
        path == AppRouter.providerDashboard ||
        path == AppRouter.welcome;
  }
}
