import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_lock_controller.dart';

/// D112 (Q-8), the owner's word: with the app lock on, the money screens
/// take no screenshot and leave no picture in the recent-apps list. The
/// other screens are untouched, and so is an account without the lock.
///
/// The window is asked to be secure while at least one money screen in
/// front holds it (Android's `FLAG_SECURE`, set by `MainActivity`). A
/// platform without the channel is left as it is.
class ScreenProtection {
  ScreenProtection._();

  static final instance = ScreenProtection._();

  @visibleForTesting
  static const channel = MethodChannel('aarast/screen_protection');

  final _holders = <Object>{};
  bool _secure = false;
  bool _pending = false;

  void hold(Object holder) {
    _holders.add(holder);
    _schedule();
  }

  void release(Object holder) {
    _holders.remove(holder);
    _schedule();
  }

  @visibleForTesting
  void resetForTest() {
    _holders.clear();
    _secure = false;
    _pending = false;
  }

  /// One money page replacing another lets go and holds within one frame;
  /// the window is asked once, for where the frame ended, so it is never
  /// open for a moment in between.
  void _schedule() {
    if (_pending) return;
    _pending = true;
    scheduleMicrotask(() {
      _pending = false;
      final secure = _holders.isNotEmpty;
      if (secure == _secure) return;
      _secure = secure;
      unawaited(_ask(secure));
    });
  }

  Future<void> _ask(bool secure) async {
    try {
      await channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // No window to ask on this platform.
    } on PlatformException {
      // The window refused; the screen is shown as it is.
    }
  }
}

/// A money screen: protected while it is in front and the account's lock is
/// on. [active] is false for a tab kept alive behind another.
class MoneyScreenShield extends StatefulWidget {
  const MoneyScreenShield({required this.child, this.active = true, super.key});

  final Widget child;
  final bool active;

  @override
  State<MoneyScreenShield> createState() => _MoneyScreenShieldState();
}

class _MoneyScreenShieldState extends State<MoneyScreenShield> {
  final _holder = Object();
  bool _holding = false;

  void _sync(bool wanted) {
    if (wanted == _holding) return;
    _holding = wanted;
    // After the frame: a page replacing another releases and holds in one
    // pass, so the window is not asked twice for nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // RA-MO-309: a screen disposed in the frame it asked in has already
      // let go in dispose; holding now would keep the window secure for
      // the whole app until restart.
      if (!mounted) return;
      if (_holding) {
        ScreenProtection.instance.hold(_holder);
      } else {
        ScreenProtection.instance.release(_holder);
      }
    });
  }

  @override
  void dispose() {
    _holding = false;
    ScreenProtection.instance.release(_holder);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool lockOn;
    try {
      lockOn = context.watch<AppLockController>().isEnabled;
    } on ProviderNotFoundException {
      lockOn = false;
    }
    _sync(widget.active && lockOn);
    return widget.child;
  }
}
