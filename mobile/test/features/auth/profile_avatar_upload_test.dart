import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
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
        'POST /media/uploads/presign user-avatar',
        'PUT https://uploads.example.com/signed image/jpeg 3',
        'PATCH /users/me https://media.example.com/user-avatar/u1/avatar.jpg',
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
          'خدمة رفع الصور غير متاحة الآن. يرجى المحاولة مرة أخرى لاحقًا.',
        ),
      ),
    );
  });

  test('More profile card wires avatar picker and iOS permissions', () {
    final moreSource = File(
      'lib/features/more/screens/more_screen.dart',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(moreSource, contains('avatarUrl: user?.avatarUrl'));
    expect(moreSource, contains('ImagePicker().pickImage'));
    expect(moreSource, contains('ImageSource.camera'));
    expect(moreSource, contains('ImageSource.gallery'));
    expect(moreSource, contains('updateAvatar('));
    expect(moreSource, contains('_avatarMaxBytes = 5 * 1024 * 1024'));
    expect(moreSource, contains('AuthActionGuard.requireAccount'));
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
    return {
      'uploadUrl': 'https://uploads.example.com/signed',
      'publicUrl': 'https://media.example.com/user-avatar/u1/avatar.jpg',
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
