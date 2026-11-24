import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-BE-133: a password change signs the other phones out and the server
// drops their push registrations; this phone names its own so it keeps
// its notices.

void main() {
  Future<Map<String, dynamic>> sent({String? fid}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final api = ApiClient(tokenProvider: () async => 'token');
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    await AuthRepository(api, storage).setPassword(
      newPassword: 'new-password-1',
      currentPassword: 'old-password-1',
      pushInstallationId: fid,
    );
    expect(adapter.path, '/api/v1/auth/password');
    return adapter.body!;
  }

  test('a password change names this phone\'s push registration', () async {
    final body = await sent(fid: 'fid-this-phone');
    expect(body['pushInstallationId'], 'fid-this-phone');
    expect(body['newPassword'], 'new-password-1');
  });

  test('a phone without a registration sends none', () async {
    final body = await sent();
    expect(body.containsKey('pushInstallationId'), isFalse);
  });

  // RA-BE-141: the first password and the phone change carry their proof.
  Future<(AuthRepository, _Adapter)> repository() async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final api = ApiClient(tokenProvider: () async => 'token');
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    return (AuthRepository(api, storage), adapter);
  }

  test('a first password sends the code to the account\'s number', () async {
    final (auth, adapter) = await repository();
    await auth.setPassword(newPassword: 'first-pass', currentCode: '123456');
    expect(adapter.body, {
      'newPassword': 'first-pass',
      'currentCode': '123456',
    });
  });

  test(
    'a phone change sends its proof beside the new number\'s code',
    () async {
      final (auth, adapter) = await repository();
      await auth.confirmPhoneChange(
        '771234567',
        '111111',
        currentPassword: 'my-password',
      );
      expect(adapter.path, '/api/v1/auth/phone-change/confirm');
      expect(adapter.body, {
        'phone': '+967771234567',
        'code': '111111',
        'currentPassword': 'my-password',
      });

      await auth.confirmPhoneChange(
        '771234567',
        '111111',
        currentCode: '222222',
      );
      expect(adapter.body, {
        'phone': '+967771234567',
        'code': '111111',
        'currentCode': '222222',
      });
    },
  );
}

class _Adapter implements HttpClientAdapter {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    body = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
