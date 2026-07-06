import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('401 refreshes once and retries with the new access token', () async {
    var token = 'old-access';
    var refreshCalls = 0;
    final adapter = _RefreshAdapter();
    final client = ApiClient(tokenProvider: () async => token);
    client.dio.httpClientAdapter = adapter;
    client.refreshSession = () async {
      refreshCalls += 1;
      token = 'new-access';
      return true;
    };

    final result = await client.getJson('/protected');

    expect(result['ok'], true);
    expect(refreshCalls, 1);
    expect(adapter.calls, 2);
  });

  test('signed byte uploads do not send the app bearer token', () async {
    final uploadDio = Dio();
    final adapter = _CaptureUploadAdapter();
    uploadDio.httpClientAdapter = adapter;
    final client = ApiClient(
      tokenProvider: () async => 'private-access-token',
      uploadDio: uploadDio,
    );

    await client.putBytes(
      'https://uploads.example.com/signed',
      Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );

    expect(adapter.authorizationHeader, isNull);
    expect(adapter.contentTypeHeader, 'image/jpeg');
    expect(adapter.contentLengthHeader, 3);
  });
}

class _RefreshAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (options.headers['Authorization'] == 'Bearer new-access') {
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"message":"expired"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CaptureUploadAdapter implements HttpClientAdapter {
  Object? authorizationHeader;
  Object? contentTypeHeader;
  Object? contentLengthHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizationHeader = options.headers['Authorization'];
    contentTypeHeader = options.headers[Headers.contentTypeHeader];
    contentLengthHeader = options.headers[Headers.contentLengthHeader];
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
