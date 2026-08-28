import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'remote push unregister uses the outgoing bearer after local session clear',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      await storage.saveSession(
        accessToken: 'outgoing-access-token',
        refreshToken: 'outgoing-refresh-token',
        user: const SafeUser(
          id: 'user-a',
          name: 'User A',
          role: 'USER',
          status: 'ACTIVE',
        ),
      );
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final adapter = _CapturingTeardownAdapter(storage);
      apiClient.dio.httpClientAdapter = adapter;
      final push = PushNotificationsController(
        preferences: preferences,
        gateway: const _AvailablePushGateway(),
        registrationApi: PushRegistrationApi(apiClient),
      );
      addTearDown(push.dispose);

      await push.initialize();
      await push.bindAuthenticatedUser('user-a');
      final coordinator = SessionTeardownCoordinator(
        auth: AuthRepository(apiClient, storage),
        push: push,
        clearLocalAccountData: () async {},
        clearGuestDraft: () async {},
      );

      await coordinator.terminate(coordinator.begin('user-a'));

      expect(await storage.readAccessToken(), isNull);
      expect(adapter.localTokenDuringPushUnregister, isNull);
      expect(
        adapter.pushUnregisterAuthorization,
        'Bearer outgoing-access-token',
      );
    },
  );
}

class _AvailablePushGateway implements PushMessagingGateway {
  const _AvailablePushGateway();

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get notificationTaps => const Stream<void>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream<PushForegroundNotification>.empty();

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async {
    return PushAuthorizationStatus.authorized;
  }

  @override
  Future<bool> consumeInitialNotificationTap() async => false;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-a';

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    return PushAuthorizationStatus.authorized;
  }
}

class _CapturingTeardownAdapter implements HttpClientAdapter {
  _CapturingTeardownAdapter(this.storage);

  final AuthStorage storage;
  String? localTokenDuringPushUnregister;
  String? pushUnregisterAuthorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE' &&
        options.path == '/api/v1/push/installations/current') {
      localTokenDuringPushUnregister = await storage.readAccessToken();
      pushUnregisterAuthorization = options.headers['Authorization']
          ?.toString();
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
