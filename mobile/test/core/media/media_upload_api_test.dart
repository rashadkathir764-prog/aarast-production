import 'dart:typed_data';

import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test(
    'image upload is verified before its storage reference is returned',
    () async {
      final api = _MediaApiClient();
      final media = MediaUploadApi(api);

      final ticket = await media.uploadImage(
        file: XFile.fromData(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
        purpose: 'chat-image',
      );

      expect(api.calls, [
        'POST /api/v1/media/uploads/presign chat-image',
        'PUT https://uploads.example.test/signed image/jpeg 4',
        'POST /api/v1/media/uploads/verify chat-image',
      ]);
      expect(ticket.attachmentRef, 'chat-image/user-1/image.jpg');
      expect(ticket.contentType, 'image/jpeg');
      expect(ticket.byteSize, 4);
    },
  );

  test('public provider image returns its verified public URL', () async {
    final api = _MediaApiClient();
    final media = MediaUploadApi(api);

    final ticket = await media.uploadImage(
      file: XFile.fromData(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
        name: 'logo.jpg',
        mimeType: 'image/jpeg',
      ),
      purpose: 'provider-logo',
    );

    expect(ticket.attachmentRef, isEmpty);
    expect(
      ticket.publicUrl,
      'https://cdn.example.test/provider-logo/user-1/image.jpg',
    );
  });

  test('unavailable media storage is always reported in Arabic', () async {
    final media = MediaUploadApi(_UnavailableMediaApiClient());

    expect(
      () => media.uploadImage(
        file: XFile.fromData(
          Uint8List.fromList([0xff, 0xd8]),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
        purpose: 'provider-logo',
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
}

class _MediaApiClient extends ApiClient {
  _MediaApiClient() : super(tokenProvider: () async => 'token');

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    calls.add('POST $path ${data['purpose']}');
    final purpose = data['purpose']?.toString() ?? '';
    final key = '$purpose/user-1/image.jpg';
    final isChat = purpose == 'chat-image';
    if (path.endsWith('/verify')) {
      return {
        'key': key,
        'attachmentRef': isChat ? key : null,
        'publicUrl': isChat ? null : 'https://cdn.example.test/$key',
        'contentType': 'image/jpeg',
        'byteSize': 4,
        'verified': true,
      };
    }
    return {
      'key': key,
      'attachmentRef': isChat ? key : null,
      'uploadUrl': 'https://uploads.example.test/signed',
      'publicUrl': isChat ? null : 'https://cdn.example.test/$key',
      'contentType': 'image/jpeg',
      'byteSize': 4,
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
