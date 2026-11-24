import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/more/screens/more_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
          'رفع الصور مش متاح الحين. جرّب بعد شوي.',
        ),
      ),
    );
  });

  // RA-TS-24: this was a grep of more_screen.dart for the names it calls.
  // It now does what a person does: opens «حسابي», presses the photo, picks
  // one, and the upload, the toast and the shown account follow.
  group('changing the photo from «حسابي»', () {
    const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    late Directory dir;
    late String pickedPath;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('avatar_pick');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, (call) async {
            if (call.method == 'pickImage') return pickedPath;
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, null);
      dir.deleteSync(recursive: true);
    });

    Future<_AvatarHarness> open(WidgetTester tester) async {
      final harness = await _AvatarHarness.create();
      await tester.pumpWidget(harness.widget);
      for (var i = 0; i < 6; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return harness;
    }

    Future<void> pickFromGallery(WidgetTester tester, Finder answer) async {
      await tester.tap(find.byTooltip('تعديل صورة الحساب'));
      await tester.pumpAndSettle();
      expect(find.text('بالكاميرا'), findsOneWidget);
      await tester.tap(find.text('من المعرض'));
      await tester.pumpAndSettle();
      // The picked file is read from the disk, outside the fake clock:
      // wait for the screen's answer, a toast, for as long as it takes.
      for (var i = 0; i < 60 && answer.evaluate().isEmpty; i += 1) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a picked photo is uploaded and the account shows it', (
      tester,
    ) async {
      final file = File('${dir.path}/me.png')
        ..writeAsBytesSync(Uint8List.fromList([9, 8, 7, 6]));
      pickedPath = file.path;
      final harness = await open(tester);

      await pickFromGallery(tester, find.text('تغيّرت صورتك.'));

      expect(harness.repository.uploads, ['me.png image/png 4 bytes 9,8,7,6']);
      expect(harness.controller.user?.avatarUrl, _avatarUrl);
      expect(find.text('تغيّرت صورتك.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a photo over 5 MB is refused before any upload', (
      tester,
    ) async {
      final file = File('${dir.path}/big.jpg')
        ..writeAsBytesSync(Uint8List(5 * 1024 * 1024 + 1));
      pickedPath = file.path;
      final harness = await open(tester);

      await pickFromGallery(tester, find.text('الصورة أكبر من 5 ميجا.'));

      expect(harness.repository.uploads, isEmpty);
      expect(find.text('الصورة أكبر من 5 ميجا.'), findsOneWidget);
      expect(harness.controller.user?.avatarUrl, isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a file that is not JPG, PNG or WebP is refused', (
      tester,
    ) async {
      final file = File('${dir.path}/note.pdf')
        ..writeAsBytesSync(Uint8List.fromList([1, 2]));
      pickedPath = file.path;
      final harness = await open(tester);

      await pickFromGallery(tester, find.textContaining('JPG أو PNG أو WebP'));

      expect(harness.repository.uploads, isEmpty);
      expect(find.textContaining('JPG أو PNG أو WebP'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  test('the iOS app says why it asks for the camera and the photos', () {
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(iosInfo, contains('NSCameraUsageDescription'));
    expect(iosInfo, contains('NSPhotoLibraryUsageDescription'));
    expect(iosInfo, contains('NSPhotoLibraryAddUsageDescription'));
  });
}

const _avatarUrl = 'https://media.example.com/avatar.jpg';

class _AvatarHarness {
  const _AvatarHarness({
    required this.widget,
    required this.repository,
    required this.controller,
  });

  final Widget widget;
  final _RecordingAvatarRepository repository;
  final AuthController controller;

  static Future<_AvatarHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _SignedInStorage(preferences);
    final repository = _RecordingAvatarRepository(storage);
    final controller = AuthController(repository);
    await controller.restoreSession();
    final device = DevicePreferences(preferences);
    return _AvatarHarness(
      repository: repository,
      controller: controller,
      widget: MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: storage),
          Provider<AuthRepository>.value(value: repository),
          Provider<GuestOnboardingStorage>.value(
            value: GuestOnboardingStorage(preferences),
          ),
          ChangeNotifierProvider<AuthController>.value(value: controller),
          ChangeNotifierProvider<DevicePreferences>.value(value: device),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MoreScreen(),
          ),
        ),
      ),
    );
  }
}

class _SignedInStorage extends AuthStorage {
  _SignedInStorage(super.preferences);

  @override
  Future<String?> readAccessToken() async => 'token';
}

class _RecordingAvatarRepository extends AuthRepository {
  _RecordingAvatarRepository(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => 'token'), storage);

  final uploads = <String>[];

  static const _user = SafeUser(
    id: 'u1',
    name: 'رشاد',
    role: 'USER',
    status: 'ACTIVE',
    phone: '+967777000000',
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
    uploads.add(
      '$fileName $contentType ${bytes.length} bytes ${bytes.join(',')}',
    );
    return const SafeUser(
      id: 'u1',
      name: 'رشاد',
      role: 'USER',
      status: 'ACTIVE',
      phone: '+967777000000',
      avatarUrl: _avatarUrl,
    );
  }
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
