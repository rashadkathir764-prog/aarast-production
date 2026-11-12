import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'avatar upload persists the public URL returned by media storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final api = _AvatarApiClient();
      final repository = AuthRepository(api, storage);

      final user = await repository.updateAvatar(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'profile.jpg',
        contentType: 'image/jpeg',
      );

      expect(api.calls, [
        'POST /api/v1/media/uploads/presign user-avatar',
        'PUT https://uploads.example.com/signed image/jpeg 3',
        'POST /api/v1/media/uploads/verify user-avatar',
        'PATCH /api/v1/users/me https://media.example.com/user-avatar/u1/avatar.jpg',
      ]);
      expect(
        user.avatarUrl,
        'https://media.example.com/user-avatar/u1/avatar.jpg',
      );
      expect(storage.readUser()?.avatarUrl, user.avatarUrl);
    },
  );

  test('AuthController exposes the updated avatar immediately', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final repository = _AvatarAuthRepository(storage);
    final controller = AuthController(repository);
    await controller.restoreSession();

    final success = await controller.updateAvatar(
      bytes: Uint8List.fromList([4, 5, 6]),
      fileName: 'camera.jpg',
      contentType: 'image/jpeg',
    );

    expect(success, isTrue);
    expect(controller.user?.avatarUrl, 'https://media.example.com/avatar.jpg');
    expect(controller.isSubmitting, isFalse);
  });

  test('unconfigured media storage returns clear Arabic feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AuthRepository(
      _UnavailableMediaApiClient(),
      AuthStorage(preferences),
    );

    expect(
      () => repository.updateAvatar(
        bytes: Uint8List.fromList([1]),
        fileName: 'profile.jpg',
        contentType: 'image/jpeg',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'رفع الصور مو متاح الحين. جرّب بعد شوي.',
        ),
      ),
    );
  });

  test('avatar is wired from one account source across More and the home', () {
    final moreSource = File(
      'lib/features/more/screens/more_screen.dart',
    ).readAsStringSync();
    final dashboardSource = File(
      'lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(moreSource, contains('avatarUrl: user?.avatarUrl'));
    expect(dashboardSource, contains('avatarUrl: auth.user?.avatarUrl'));
    expect(moreSource, contains('ImagePicker().pickImage'));
    expect(moreSource, contains('ImageSource.camera'));
    expect(moreSource, contains('ImageSource.gallery'));
    expect(moreSource, contains('updateAvatar('));
    expect(moreSource, contains('_avatarMaxBytes = 5 * 1024 * 1024'));
    expect(moreSource, contains('AuthActionGuard.requireAccount'));
    expect(moreSource, isNot(contains('NotificationsProvider')));
    expect(iosInfo, contains('NSCameraUsageDescription'));
    expect(iosInfo, contains('NSPhotoLibraryUsageDescription'));
    expect(iosInfo, contains('NSPhotoLibraryAddUsageDescription'));
  });
}

class _UnavailableMediaApiClient extends ApiClient {
  _UnavailableMediaApiClient() : super(tokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) {
    throw const ApiException(
      'Media storage is not configured',
      statusCode: 503,
    );
  }
}

class _AvatarAuthRepository extends AuthRepository {
  _AvatarAuthRepository(AuthStorage storage)
    : super(_AvatarApiClient(), storage);

  SafeUser get _user => const SafeUser(
    id: 'u1',
    name: 'Aarast Admin',
    role: 'USER',
    status: 'ACTIVE',
    phone: '+96777758200',
  );

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<SafeUser> me() async => _user;

  @override
  Future<SafeUser> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return const SafeUser(
      id: 'u1',
      name: 'Aarast Admin',
      role: 'USER',
      status: 'ACTIVE',
      phone: '+96777758200',
      avatarUrl: 'https://media.example.com/avatar.jpg',
    );
  }
}

class _AvatarApiClient extends ApiClient {
  _AvatarApiClient() : super(tokenProvider: () async => 'token');

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    calls.add('POST $path ${data['purpose']}');
    if (path.endsWith('/verify')) {
      return {
        'key': data['key'],
        'attachmentRef': data['key'],
        'publicUrl': 'https://media.example.com/user-avatar/u1/avatar.jpg',
        'contentType': 'image/jpeg',
        'byteSize': 3,
        'verified': true,
      };
    }
    return {
      'key': 'user-avatar/u1/avatar.jpg',
      'attachmentRef': 'user-avatar/u1/avatar.jpg',
      'uploadUrl': 'https://uploads.example.com/signed',
      'publicUrl': 'https://media.example.com/user-avatar/u1/avatar.jpg',
      'contentType': 'image/jpeg',
      'byteSize': 3,
    };
  }

  @override
  Future<void> putBytes(
    String url,
    Uint8List bytes, {
    required String contentType,
  }) async {
    calls.add('PUT $url $contentType ${bytes.length}');
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    calls.add('PATCH $path ${data['avatarUrl']}');
    return {
      'id': 'u1',
      'name': 'Aarast Admin',
      'phone': '+96777758200',
      'role': 'USER',
      'status': 'ACTIVE',
      'avatarUrl': data['avatarUrl'],
    };
  }
}
