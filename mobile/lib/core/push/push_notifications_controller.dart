import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/context_lifecycle_logger.dart';
import 'push_messaging_gateway.dart';
import 'push_registration_api.dart';

const pushPermissionRequestedPreferenceKey =
    'aarast.push.permission_requested.v1';

class PushNotificationsController extends ChangeNotifier {
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

  bool get isAvailable => _initialized && _gateway.isAvailable;
  bool get hasPendingNotificationsOpen => _pendingNotificationsOpen;

  Future<void> initialize() async {
    if (_initialized || !_gateway.isAvailable) return;
    try {
      await _gateway.initialize();
      _initialized = true;
      _subscriptions
        ..add(
          _gateway.installationChanges.listen((_) {
            _registeredFid = null;
            unawaited(_queueCurrentRegistration());
          }),
        )
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
      ContextLifecycleLogger.event(
        'PUSH_INITIALIZATION_FAILED',
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

  Future<void> bindAuthenticatedUser(String? userId) {
    final normalized = userId?.trim();
    final nextUserId = normalized?.isNotEmpty == true ? normalized : null;
    if (_boundUserId == nextUserId) return Future<void>.value();
    _boundUserId = nextUserId;
    _registeredFid = null;
    ++_bindingGeneration;
    return _queueCurrentRegistration();
  }

  Future<void> unregisterAccount(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty || _boundUserId != normalized) {
      return Future<void>.value();
    }
    final operation = ++_bindingGeneration;
    return _enqueueDeviceOperation(() async {
      if (!_isCurrentBinding(operation, normalized)) return;
      final fid = _registeredFid;
      if (fid != null) {
        try {
          await _registrationApi
              .unregisterAndroid(fid)
              .timeout(const Duration(milliseconds: 1500));
        } on Object {
          // Local deletion below stops this device even when the backend is
          // temporarily unavailable. The stale FID is purged after FCM rejects it.
        }
      }
      if (!_isCurrentBinding(operation, normalized)) return;
      await _gateway.deleteLocalRegistration();
      if (!_isCurrentBinding(operation, normalized)) return;
      _registeredFid = null;
      _boundUserId = null;
    });
  }

  Future<void> clearLocalRegistrationForAccount(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty || _boundUserId != normalized) {
      return Future<void>.value();
    }
    final operation = ++_bindingGeneration;
    return _enqueueDeviceOperation(() async {
      if (!_isCurrentBinding(operation, normalized)) return;
      await _gateway.deleteLocalRegistration();
      if (!_isCurrentBinding(operation, normalized)) return;
      _registeredFid = null;
      _boundUserId = null;
    });
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
    if (userId == null) return Future<void>.value();
    return _enqueueDeviceOperation(() => _registerIfAllowed(operation, userId));
  }

  Future<void> _registerIfAllowed(int operation, String userId) async {
    if (!isAvailable || !_isCurrentBinding(operation, userId)) return;
    try {
      final permission = await _gateway.authorizationStatus();
      if (permission != PushAuthorizationStatus.authorized ||
          !_isCurrentBinding(operation, userId)) {
        return;
      }
      final fid = await _gateway.ensureRegistrationAndGetInstallationId();
      if (!_isCurrentBinding(operation, userId)) return;
      await _registrationApi.registerAndroid(fid);
      if (!_isCurrentBinding(operation, userId)) return;
      _registeredFid = fid;
      ContextLifecycleLogger.event(
        'PUSH_INSTALLATION_REGISTERED',
        userId: userId,
        reason: 'authorized_device',
        source: 'PushNotificationsController',
      );
    } on Object {
      ContextLifecycleLogger.event(
        'PUSH_INSTALLATION_REGISTRATION_FAILED',
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

  bool _isCurrentBinding(int operation, String userId) {
    return operation == _bindingGeneration && _boundUserId == userId;
  }

  void _markNotificationsOpenPending() {
    if (_pendingNotificationsOpen) return;
    _pendingNotificationsOpen = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
