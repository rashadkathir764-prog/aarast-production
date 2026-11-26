import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/app_logger.dart';
import '../network/server_reachability.dart';
import '../session/session_teardown_coordinator.dart';
import 'notice_arrivals.dart';
import 'open_conversation.dart';
import 'push_messaging_gateway.dart';
import 'push_registration_api.dart';
import 'push_system_notifications.dart';

const pushPermissionRequestedPreferenceKey =
    'aarast.push.permission_requested.v1';

/// Android 13 (API 33): from it on the app asks for notifications itself.
const _askedNotificationsFromSdk = 33;

/// Why the phone's question is asked now: the explanation before it says
/// what the alerts are for, as the reader's role needs.
enum PushPermissionReason {
  /// A plan made or a reminder set: dates, payments, the providers' answers.
  plan,

  /// A provider's application sent: the team's decision and new requests.
  provider,

  /// A plan joined from an invitation: the tasks given to the reader.
  participant,
}

/// What this phone does with the app's alerts, as the settings page says it.
enum PushPhoneState {
  /// No phone alerts here at all: no Google services, a registration that
  /// failed, or a build without Firebase. The alerts stay in the app.
  unavailable,

  /// The app never asked the phone: one tap asks it.
  notAsked,

  /// The person turned them off: only the phone's own settings turn them on.
  off,

  /// They reach the phone.
  on,

  /// The phone did not say; nothing is claimed.
  unknown,
}

class PushNotificationsController extends ChangeNotifier
    implements SessionPushTeardownPort {
  PushNotificationsController({
    required SharedPreferences preferences,
    required PushMessagingGateway gateway,
    required PushInstallationRegistry registrationApi,
    PushSystemNotifications systemNotifications =
        const NoPushSystemNotifications(),
    OpenConversationRegistry? openConversations,
    NoticeArrivals? noticeArrivals,
    ServerReachability? reachability,
    Future<bool> Function()? openPhoneNotificationSettings,
  }) : _preferences = preferences,
       _gateway = gateway,
       _registrationApi = registrationApi,
       _system = systemNotifications,
       _openConversations = openConversations,
       _noticeArrivals = noticeArrivals,
       _reachability = reachability,
       _openPhoneSettings =
           openPhoneNotificationSettings ??
           PlayServicesCheck.openNotificationSettings,
       _wasReachable = reachability?.reachable ?? true {
    reachability?.addListener(_onReachabilityChanged);
  }

  final Future<bool> Function() _openPhoneSettings;
  final SharedPreferences _preferences;
  final PushMessagingGateway _gateway;
  final PushInstallationRegistry _registrationApi;
  final PushSystemNotifications _system;
  final OpenConversationRegistry? _openConversations;
  final NoticeArrivals? _noticeArrivals;
  final ServerReachability? _reachability;
  bool _wasReachable;

  final List<StreamSubscription<void>> _subscriptions = [];
  Future<void> _deviceOperation = Future<void>.value();
  String? _boundUserId;
  String? _registeredFid;
  bool _initialized = false;
  bool _pendingNotificationsOpen = false;
  PushNotificationTap? _pendingTap;
  int _bindingGeneration = 0;
  CancelToken? _bindingCancelToken;

  /// This phone's push registration, so a password change keeps it while
  /// the server drops the other phones' (RA-BE-133); null when none.
  String? get registeredFid => _registeredFid;

  bool get isAvailable => _initialized && _gateway.isAvailable;

  /// RA-MO-359: push cannot work on this phone: it has no Google services
  /// (a Huawei phone), or the registration with them failed. Said by the
  /// home's card, so the reader knows alerts stay in the app; a later
  /// registration that succeeds takes it back.
  bool get unavailableOnThisPhone => _noGoogleServices || _registrationFailed;
  bool _noGoogleServices = false;
  bool _registrationFailed = false;
  bool get hasPendingNotificationsOpen => _pendingNotificationsOpen;

  /// The gateway's foreground pushes once set up. The app's root listens
  /// from its first build, which comes before [initialize] (it runs after
  /// the first frame), so the stream is the controller's own.
  Stream<PushForegroundNotification> get foregroundNotifications =>
      _foreground.stream;
  final _foreground = StreamController<PushForegroundNotification>.broadcast();

  /// [requestPermissionOnFirstOpen] came before [initialize]: it is asked
  /// once push is set up.
  bool _permissionAskedEarly = false;

  /// Push is set up after the first frame, not before it: Firebase's
  /// messaging, its listeners and the first registration are not on the way
  /// to the first screen. Whatever the app asked meanwhile (the account
  /// bound, the permission asked, the foreground stream listened to) is
  /// served here, and listeners are told it is available.
  Future<void> initialize() {
    final running = _initializing;
    if (running != null) return running;
    final setUp = _initialize();
    _initializing = setUp;
    return setUp.whenComplete(() {
      // A failed set-up may be tried again.
      if (!_initialized && identical(_initializing, setUp)) {
        _initializing = null;
      }
    });
  }

  /// The set-up under way, so a question asked meanwhile waits for it.
  Future<void>? _initializing;

  Future<void> _initialize() async {
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
        ..add(_gateway.notificationTaps.listen(_markNotificationsOpenPending))
        ..add(_gateway.foregroundNotifications.listen(_onForegroundPush))
        ..add(_system.taps.listen(_markNotificationsOpenPending));
      final initialTap = await _gateway.consumeInitialNotificationTap();
      if (initialTap != null) _markNotificationsOpenPending(initialTap);
      // A notification shown while the app was open, tapped after it closed.
      await _system.initialize();
      final launchTap = await _system.consumeLaunchTap();
      if (launchTap != null) _markNotificationsOpenPending(launchTap);
    } on PushUnavailableOnThisPhone {
      _initialized = false;
      _noGoogleServices = true;
      appLogEvent(
        'PUSH_INITIALIZATION_SKIPPED',
        category: AppLogCategory.push,
        level: AppLogLevel.warning,
        reason: 'no_google_services',
        source: 'PushNotificationsController.initialize',
      );
      notifyListeners();
      return;
    } on Object {
      _initialized = false;
      appLogEvent(
        'PUSH_INITIALIZATION_FAILED',
        category: AppLogCategory.push,
        level: AppLogLevel.error,
        reason: 'firebase_initialization_failed',
        source: 'PushNotificationsController.initialize',
      );
      return;
    }
    notifyListeners();
    if (_permissionAskedEarly) {
      _permissionAskedEarly = false;
      await requestPermissionOnFirstOpen();
    } else {
      await _queueCurrentRegistration();
    }
  }

  Future<void> requestPermissionOnFirstOpen() async {
    if (!isAvailable) {
      if (!_initialized && _gateway.isAvailable) _permissionAskedEarly = true;
      return;
    }
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

  /// The phone's notification permission as the person set it. From
  /// Android 13 the plugin says «denied» before the app ever asked (it knows
  /// only granted or not): never asked by this app, that «denied» is a
  /// question still to ask. Below 13 notifications are on unless the person
  /// turned them off, so «denied» there is theirs.
  Future<PushAuthorizationStatus> _authorization() async {
    final status = await _gateway.authorizationStatus();
    if (status != PushAuthorizationStatus.denied ||
        _preferences.getBool(pushPermissionRequestedPreferenceKey) == true) {
      return status;
    }
    final sdk = await (_sdkInt ??= _gateway.androidSdkInt().then(
      (value) => value,
      onError: (Object _) => null,
    ));
    return sdk != null && sdk >= _askedNotificationsFromSdk
        ? PushAuthorizationStatus.notDetermined
        : status;
  }

  /// The phone's Android version, asked once.
  Future<int?>? _sdkInt;

  /// A push that arrived while the app is in front. The inbox and the bell
  /// read their count again; the phone's own notification says it, unless
  /// the reader has its conversation open (the message is on the screen).
  /// A phone that will not show it (notifications off) gets the in-app line.
  Future<void> _onForegroundPush(PushForegroundNotification push) async {
    _noticeArrivals?.announce();
    final conversation = push.conversationId;
    if (conversation != null &&
        _openConversations?.isOpen(conversation) == true) {
      return;
    }
    var shown = false;
    try {
      shown =
          await _authorization() == PushAuthorizationStatus.authorized &&
          await _system.show(push);
    } on Object {
      shown = false;
    }
    if (!shown && !_foreground.isClosed) _foreground.add(push);
  }

  /// RA-MO-343's «the server answers again» seen from push: what the phone
  /// missed meanwhile is read again (the count), and the registration that
  /// may have failed without a network is made again.
  void _onReachabilityChanged() {
    final reachable = _reachability?.reachable ?? true;
    final cameBack = reachable && !_wasReachable;
    _wasReachable = reachable;
    if (!cameBack) return;
    unawaited(_queueCurrentRegistration());
    _noticeArrivals?.announce();
  }

  bool _explanationPending = false;
  bool _explainedThisSession = false;
  PushPermissionReason _explanationReason = PushPermissionReason.plan;

  /// RA-MO-360: the phone's «اسمح بالإشعارات» question waits for a reason: a
  /// reminder set, or the first plan made. At that moment ([permissionMomentReached])
  /// the app says in one line what the alerts are for, and only an «اسمح» on
  /// that sheet asks the phone ([requestPermissionOnFirstOpen]). True while
  /// the line waits to be shown.
  bool get hasPendingPermissionExplanation => _explanationPending;

  /// What the waiting explanation is for.
  PushPermissionReason get permissionExplanationReason => _explanationReason;

  /// A moment that gives the question a reason. It explains only where the
  /// phone would still ask (an account, push working here, never asked,
  /// notifications neither on nor turned off), and once a session.
  Future<void> permissionMomentReached({
    PushPermissionReason reason = PushPermissionReason.plan,
  }) async {
    await _initializing;
    if (_explainedThisSession ||
        _explanationPending ||
        !isAvailable ||
        _boundUserId == null ||
        _preferences.getBool(pushPermissionRequestedPreferenceKey) == true) {
      return;
    }
    final PushAuthorizationStatus status;
    try {
      status = await _authorization();
    } on Object {
      return;
    }
    if (status != PushAuthorizationStatus.notDetermined ||
        _explanationPending ||
        _explainedThisSession) {
      return;
    }
    _explanationReason = reason;
    _explanationPending = true;
    notifyListeners();
  }

  /// The explanation waiting to be shown, once; false when none waits.
  bool claimPermissionExplanation() {
    if (!_explanationPending) return false;
    _explanationPending = false;
    _explainedThisSession = true;
    notifyListeners();
    return true;
  }

  /// w39: the phone has this app's notifications turned off.
  Future<bool> isTurnedOff() async {
    // The first screen asks right after its first frame, while push is
    // being set up.
    await _initializing;
    if (!isAvailable) return false;
    try {
      return await _authorization() == PushAuthorizationStatus.denied;
    } on Object {
      return false;
    }
  }

  /// w39 «افتح الإعدادات»: this app's notification settings in the phone.
  /// Turned off by the person, they come back on there only: asking again
  /// shows nothing on a phone refused twice (Android 13+) or below 13. The
  /// page that opened them reads [phoneState] again when the app is back
  /// in front. False when the phone would not open them.
  Future<bool> openPhoneSettings() async {
    try {
      return await _openPhoneSettings();
    } on Object {
      return false;
    }
  }

  /// The registration once the person turned them on in the phone's
  /// settings: called when a page sees [PushPhoneState.on] again.
  Future<void> turnedOnInPhoneSettings() => _queueCurrentRegistration();

  /// The settings page's banner: what the phone does with the alerts now.
  Future<PushPhoneState> phoneState() async {
    await _initializing;
    if (!isAvailable || unavailableOnThisPhone) return PushPhoneState.unavailable;
    try {
      return switch (await _authorization()) {
        PushAuthorizationStatus.authorized => PushPhoneState.on,
        PushAuthorizationStatus.denied => PushPhoneState.off,
        PushAuthorizationStatus.notDetermined => PushPhoneState.notAsked,
      };
    } on Object {
      return PushPhoneState.unknown;
    }
  }

  /// «اسمح بالتنبيهات» on the settings page: asks the phone its question,
  /// once, and says what it answered.
  Future<PushPhoneState> askFromSettings() async {
    await requestPermissionOnFirstOpen();
    final state = await phoneState();
    notifyListeners();
    return state;
  }

  Future<void> bindAuthenticatedUser(String? userId) {
    final normalized = userId?.trim();
    final nextUserId = normalized?.isNotEmpty == true ? normalized : null;
    if (_boundUserId == nextUserId) return Future<void>.value();
    // The notifications in the tray were the other account's.
    if (_boundUserId != null) unawaited(_system.cancelAll());
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
    // The account's notices leave the phone with it, the tray's too.
    unawaited(_system.cancelAll());
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

  /// The tap waiting to be opened, once; null when none waits.
  PushNotificationTap? claimNotificationsOpen() {
    if (!_pendingNotificationsOpen) return null;
    final tap = _pendingTap;
    _pendingNotificationsOpen = false;
    _pendingTap = null;
    notifyListeners();
    return tap ?? const PushNotificationTap();
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
      final permission = await _authorization();
      if (permission != PushAuthorizationStatus.authorized ||
          !_isCurrentBinding(operation, userId, cancelToken)) {
        return;
      }
      final String fid;
      try {
        fid = await _gateway.ensureRegistrationAndGetInstallationId();
      } on Object {
        // The phone's own registration with Google failed: no server call
        // can fix it, so the card says push does not work here.
        _setRegistrationFailed(true);
        rethrow;
      }
      _setRegistrationFailed(false);
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

  void _setRegistrationFailed(bool failed) {
    if (_registrationFailed == failed) return;
    _registrationFailed = failed;
    notifyListeners();
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

  void _markNotificationsOpenPending(PushNotificationTap tap) {
    // The last tap is the one the person means.
    _pendingTap = tap;
    if (_pendingNotificationsOpen) return;
    _pendingNotificationsOpen = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _reachability?.removeListener(_onReachabilityChanged);
    _cancelAndResetBindingOperations('Push controller disposed');
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_foreground.close());
    super.dispose();
  }
}
