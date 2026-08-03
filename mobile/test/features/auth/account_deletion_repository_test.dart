import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'delete account accepts only an explicit deleted true response',
    () async {
      final confirmed = await _repositoryFor({'deleted': true});
      await confirmed.deleteAccount(clientRequestId: 'delete-request-1');

      final malformed = await _repositoryFor({'deleted': false});
      await expectLater(
        malformed.deleteAccount(clientRequestId: 'delete-request-1'),
        throwsA(isA<FormatException>()),
      );

      final missing = await _repositoryFor({'status': 'ok'});
      await expectLater(
        missing.deleteAccount(clientRequestId: 'delete-request-1'),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

Future<AuthRepository> _repositoryFor(Map<String, Object?> response) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final api = ApiClient(tokenProvider: storage.readAccessToken);
  api.dio.httpClientAdapter = _DeletionAdapter(response);
  return AuthRepository(api, storage);
}

class _DeletionAdapter implements HttpClientAdapter {
  _DeletionAdapter(this.response);

  final Map<String, Object?> response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.method, 'DELETE');
    expect(options.path, '/api/v1/users/me');
    expect(
      options.headers[ApiClient.clientRequestIdHeader],
      'delete-request-1',
    );
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
