import 'package:flutter/foundation.dart';

abstract interface class SessionScopedState {
  void bindSessionIdentity(Object identity);
  bool belongsToSession(Object identity);
}

/// A notifier owned by an account/plan keyed subtree.
///
/// Requests from a disposed session may still finish after logout. Their
/// results remain unreachable, and this guard prevents a late notification
/// from touching the replacement session's widget tree.
mixin SessionScopedNotifier on ChangeNotifier implements SessionScopedState {
  bool _sessionDisposed = false;
  Object? _sessionIdentity;

  @protected
  bool get isSessionDisposed => _sessionDisposed;

  @override
  void bindSessionIdentity(Object identity) {
    _sessionIdentity = identity;
  }

  @override
  bool belongsToSession(Object identity) {
    return !_sessionDisposed && _sessionIdentity == identity;
  }

  @override
  void notifyListeners() {
    if (_sessionDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _sessionDisposed = true;
    super.dispose();
  }
}
