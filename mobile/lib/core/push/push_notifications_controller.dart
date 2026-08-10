import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/app_logger.dart';
import '../session/session_teardown_coordinator.dart';
import 'push_messaging_gateway.dart';
import 'push_registration_api.dart';

const pushPermissionRequestedPreferenceKey =
    'aarast.push.permission_requested.v1';

class PushNotificationsController extends ChangeNotifier
    implements SessionPushTeardownPort {
  PushNotificationsController({
    required SharedPreferences preferences,
    required PushMessagingGateway gateway,
    required PushInstallationRegistry registrationApi,
  }) : _preferences = preferences,
       _gateway = gateway,
       _registrationApi = registrationApi;

  final SharedPreferences _preferences;
  final PushMessagingGateway _gateway;
  final PushInstallationRegistry _registrationApi;

  final List<StreamSubscription<void>> _subscriptions = [];
  Future<void> _deviceOperation = Future<void>.value();
  String? _boundUserId;
  String? _registeredFid;
  bool _initialized = false;
  bool _pendingNotificationsOpen = false;
  int _bindingGeneration = 0;
  CancelToken? _bindingCancelToken;

  bool get isAvailable => _initialized && _gateway.isAvailable;
  bool get hasPendingNotificationsOpen => _pendingNotificationsOpen;
  Stream<PushForegroundNotification> get foregroundNotifications => isAvailable
      ? _gateway.foregroundNotifications
      : const Stream<PushForegroundNotification>.empty();

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_gateway.isAvailable) {
      appLogEvent(
        'PUSH_INITIALIZATION_SKIPPED',
        category: AppLogCategory.push,
        reason: 'gateway_unavailable',
        source: 'PushNotificationsController.initialize',
      );
      return;
    }
    appLogEvent(
      'PUSH_INITIALIZATION_STARTED',
      category: AppLogCategory.push,
      source: 'PushNotificationsController.initialize',
    );
    try {
      await _gateway.initialize();
      _initialized = true;
      appLogEvent(
        'PUSH_INITIALIZATION_COMPLETED',
        category: AppLogCategory.push,
        source: 'PushNotificationsController.initialize',
      );
      _subscriptions
        ..add(
          _gateway.tokenChanges.listen((_) {
            unawaited(_queueCurrentRegistration());
          }),
        )
        ..add(
          _gateway.notificationTaps.listen((_) {
            _markNotificationsOpenPending();
          }),
        );
      if (await _gateway.consumeInitialNotificationTap()) {
        _markNotificationsOpenPending();
      }
    } on Object {
      _initialized = false;
      appLogEvent(
        'PUSH_INITIALIZATION_FAILED',
        category: AppLogCategory.push,
        level: AppLogLevel.error,
        reason: 'firebase_initialization_failed',
        source: 'PushNotificationsController.initialize',
      );
    }
  }

  Future<void> requestPermissionOnFirstOpen() async {
    if (!isAvailable) return;
    final alreadyRequested =
        _preferences.getBool(pushPermissionRequestedPreferenceKey) == true;
    if (!alreadyRequested) {
      await _preferences.setBool(pushPermissionRequestedPreferenceKey, true);
      try {
        await _gateway.requestPermission();
      } on Object {
        await _preferences.remove(pushPermissionRequestedPreferenceKey);
        return;
      }
    }
    await _queueCurrentRegistration();
  }

  Future<void> refreshCurrentRegistration() => _queueCurrentRegistration();

  Future<void> bindAuthenticatedUser(String? userId) {
    final normalized = userId?.trim();
    final nextUserId = normalized?.isNotEmpty == true ? normalized : null;
    if (_boundUserId == nextUserId) return Future<void>.value();
    _boundUserId = nextUserId;
    _registeredFid = null;
    ++_bindingGeneration;
    _cancelAndResetBindingOperations('Push account binding changed');
    if (nextUserId != null) {
      _bindingCancelToken = CancelToken();
    }
    return _queueCurrentRegistration();
  }

  Future<void> unregisterAccount(String userId) async {
    final lease = beginAccountTeardown(userId);
    if (lease == null) return;
    final cancelToken = CancelToken();
    try {
      await unregisterRemote(
        lease,
        cancelToken: cancelToken,
      ).timeout(const Duration(milliseconds: 1500));
    } on TimeoutException {
      cancelToken.cancel('Push unregister deadline reached');
    } on Object {
      // Account logout remains local-first even when remote unregister fails.
      // A later account registration atomically rebinds this device FID.
    }
    await clearLocalRegistration(lease);
  }

  Future<void> clearLocalRegistrationForAccount(String userId) async {
    final lease = beginAccountTeardown(userId);
    if (lease == null) return;
    await clearLocalRegistration(lease);
  }

  @override
  SessionPushTeardownLease? beginAccountTeardown(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty || _boundUserId != normalized) {
      return null;
    }
    final operation = ++_bindingGeneration;
    _cancelAndResetBindingOperations('Push account teardown started');
    final lease = SessionPushTeardownLease(
      userId: normalized,
      installationId: _registeredFid,
      bindingGeneration: operation,
    );
    appLogEvent(
      'PUSH_UNREGISTER_STARTED',
      category: AppLogCategory.push,
      userId: normalized,
      source: 'PushNotificationsController.beginAccountTeardown',
      attributes: {'fid': ?lease.installationId},
    );
    _registeredFid = null;
    _boundUserId = null;
    return lease;
  }

  @override
  Future<void> clearLocalRegistration(SessionPushTeardownLease lease) async {
    if (lease.bindingGeneration != _bindingGeneration || _boundUserId != null) {
      return;
    }
    // FID and FCM token identify this app installation, not an Aarast account.
    // Keep them stable across account changes. The account-scoped server
    // binding is removed by unregisterRemote under the shared remote deadline.
    _registeredFid = null;
    appLogEvent(
      'PUSH_LOCAL_BINDING_CLEARED',
      category: AppLogCategory.push,
      userId: lease.userId,
      source: 'PushNotificationsController.clearLocalRegistration',
      attributes: {'fid': ?lease.installationId},
    );
  }

  @override
  Future<void> unregisterRemote(
    SessionPushTeardownLease lease, {
    required CancelToken cancelToken,
    String? bearerToken,
  }) async {
    final fid = lease.installationId;
    if (fid == null || fid.isEmpty) {
      appLogEvent(
        'PUSH_REMOTE_UNREGISTER_SKIPPED',
        category: AppLogCategory.push,
        userId: lease.userId,
        reason: 'missing_installation_binding',
        source: 'PushNotificationsController.unregisterRemote',
      );
      return;
    }
    try {
      await _registrationApi.unregisterAndroid(
        fid,
        cancelToken: cancelToken,
        bearerToken: bearerToken,
      );
      appLogEvent(
        'PUSH_REMOTE_UNREGISTER_COMPLETED',
        category: AppLogCategory.push,
        userId: lease.userId,
        source: 'PushNotificationsController.unregisterRemote',
        attributes: {'fid': fid},
      );
    } on Object {
      appLogEvent(
        'PUSH_REMOTE_UNREGISTER_FAILED',
        category: AppLogCategory.push,
        level: AppLogLevel.warning,
        userId: lease.userId,
        reason: 'transport_failed_or_cancelled',
        source: 'PushNotificationsController.unregisterRemote',
        attributes: {'fid': fid},
      );
      rethrow;
    }
  }

  bool claimNotificationsOpen() {
    if (!_pendingNotificationsOpen) return false;
    _pendingNotificationsOpen = false;
    notifyListeners();
    return true;
  }

  Future<void> _queueCurrentRegistration() {
    final userId = _boundUserId;
    final operation = _bindingGeneration;
    final cancelToken = _bindingCancelToken;
    if (userId == null || cancelToken == null || cancelToken.isCancelled) {
      return Future<void>.value();
    }
    return _enqueueDeviceOperation(
      () => _registerIfAllowed(operation, userId, cancelToken),
    );
  }

  Future<void> _registerIfAllowed(
    int operation,
    String userId,
    CancelToken cancelToken,
  ) async {
    if (!isAvailable || !_isCurrentBinding(operation, userId, cancelToken)) {
      return;
    }
    try {
      final permission = await _gateway.authorizationStatus();
      if (permission != PushAuthorizationStatus.authorized ||
          !_isCurrentBinding(operation, userId, cancelToken)) {
        return;
      }
      final fid = await _gateway.ensureRegistrationAndGetInstallationId();
      if (!_isCurrentBinding(operation, userId, cancelToken)) return;
      await _registrationApi.registerAndroid(fid, cancelToken: cancelToken);
      if (!_isCurrentBinding(operation, userId, cancelToken)) return;
      _registeredFid = fid;
      appLogEvent(
        'PUSH_INSTALLATION_REGISTERED',
        category: AppLogCategory.push,
        userId: userId,
        reason: 'authorized_device',
        source: 'PushNotificationsController',
        attributes: {'fid': fid},
      );
    } on Object {
      appLogEvent(
        'PUSH_INSTALLATION_REGISTRATION_FAILED',
        category: AppLogCategory.push,
        level: AppLogLevel.warning,
        userId: userId,
        reason: 'registration_failed',
        source: 'PushNotificationsController',
      );
    }
  }

  Future<void> _enqueueDeviceOperation(Future<void> Function() operation) {
    final completion = _deviceOperation.then((_) => operation());
    _deviceOperation = completion.catchError((_) {});
    return completion;
  }

  void _cancelAndResetBindingOperations(String reason) {
    final cancelToken = _bindingCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _bindingCancelToken = null;
    // Firebase calls cannot be cancelled. Detach the new account from an old
    // stalled queue; generation checks prevent the old result from mutating
    // local state or starting a later server registration.
    _deviceOperation = Future<void>.value();
  }

  bool _isCurrentBinding(
    int operation,
    String userId,
    CancelToken cancelToken,
  ) {
    return operation == _bindingGeneration &&
        _boundUserId == userId &&
        identical(_bindingCancelToken, cancelToken) &&
        !cancelToken.isCancelled;
  }

  void _markNotificationsOpenPending() {
    if (_pendingNotificationsOpen) return;
    _pendingNotificationsOpen = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAndResetBindingOperations('Push controller disposed');
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
