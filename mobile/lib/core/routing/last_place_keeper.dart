import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'aarast_back_button_dispatcher.dart';
import 'app_router.dart';

/// The pages a person passes through to get into the app. None of them is
/// a place to be brought back to.
const _doorPaths = {
  AppRouter.splash,
  AppRouter.welcome,
  AppRouter.onboarding,
  AppRouter.login,
  AppRouter.register,
  AppRouter.resetPassword,
  AppRouter.otp,
};

/// [location] when it is a page inside the app that can be opened again by
/// its address; null for a door, for anything outside the app, and for
/// nothing.
String? resumableLocation(String? location) {
  final value = location?.trim() ?? '';
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (_doorPaths.contains(uri.path)) return null;
  return value;
}

/// y06/y07, y08 and y09: the pages that celebrate something once.
bool _celebratesOnce(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length < 4 || segments.first != 'wedding-plans') return false;
  final rest = segments.sublist(2);
  return rest.first == 'moments' ||
      (rest.length == 3 &&
          rest[0] == 'money' &&
          rest[1] == 'mahr' &&
          rest[2] == 'moment') ||
      (rest.length == 3 && rest[0] == 'providers' && rest[1] == 'booked');
}

/// Where the app comes back to when the system closed it on [location]:
/// the page itself, or the page a one-time celebration belongs to (it was
/// seen; it is not played again). Null when there is no place to keep.
String? placeToReturnTo(String? location) {
  final place = resumableLocation(location);
  if (place == null) return null;
  final uri = Uri.parse(place);
  if (!_celebratesOnce(uri)) return place;
  return AarastBackButtonDispatcher.fallbackLocationFor(uri);
}

/// Brings the app back to the page it was on when the system closed it.
///
/// RA-MO-312: Android closes an app left in the background when it needs
/// the memory, and coming back started the app from its opening screen (the
/// night sky and the fireworks for a second) and then the home: it read as
/// a celebration out of place, and the page the person was on was lost.
/// The place is kept in what Android saves for the app when it closes it
/// this way, and gives back only then: an app opened anew, or one the
/// person swiped away, starts from its opening as before.
///
/// Only the address is kept, never what a page was holding; the page's own
/// gates decide what the reader may see, as for a link.
class LastPlaceKeeper extends StatelessWidget {
  const LastPlaceKeeper({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RootRestorationScope(
      restorationId: 'aarast',
      child: _Keeper(router: router, child: child),
    );
  }
}

class _Keeper extends StatefulWidget {
  const _Keeper({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_Keeper> createState() => _KeeperState();
}

class _KeeperState extends State<_Keeper> with RestorationMixin {
  final _place = RestorableStringN(null);

  /// The place being returned to; until the router is there the opening
  /// screen is not built, so it is never seen.
  String? _returningTo;

  @override
  String get restorationId => 'last_place';

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_notePlace);
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_place, 'place');
    if (!initialRestore) return;
    final place = placeToReturnTo(_place.value);
    if (place == null) return;
    _returningTo = place;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(place);
      setState(() => _returningTo = null);
    });
  }

  void _notePlace() {
    if (_returningTo != null) return;
    _place.value = placeToReturnTo(widget.router.state.uri.toString());
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_notePlace);
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_returningTo != null) return const SizedBox.shrink();
    // The address alone is kept, here. The pages under this get no bucket:
    // the router would otherwise restore its own stack, with what each page
    // was opened with, and the doors and the celebrations with it.
    return UnmanagedRestorationScope(child: widget.child);
  }
}
