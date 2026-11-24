import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/client_device_id.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RA-BE-140, RA-BE-144, RA-BE-148: the server counts its code and password
/// limits by the phone's own random id beside the network address, so people
/// behind one shared mobile address are not closed out together. The id is
/// made once and sent only where those limits read it.
void main() {
  test('the phone id is made once and kept', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final first = await readOrCreateClientDeviceId(preferences);
    final again = await readOrCreateClientDeviceId(preferences);

    expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(again, first);
  });

  test(
    'sign-in and code requests carry the phone id; other requests do not',
    () async {
      final adapter = _Adapter();
      final client = ApiClient(
        tokenProvider: () async => null,
        deviceId: '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
      )..dio.httpClientAdapter = adapter;

      await client.postJson('/api/v1/auth/login', const {});
      await client.postJson('/api/v1/auth/otp/request', const {});
      await client.postJson('/api/v1/invites/abc/request-otp', const {});
      await client.getJson('/api/v1/wedding-plans');

      expect(adapter.devices, [
        '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
        '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
        '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
        null,
      ]);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final List<String?> devices = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    devices.add(options.headers[clientDeviceHeader]?.toString());
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
