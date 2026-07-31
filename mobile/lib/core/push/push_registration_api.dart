import 'package:dio/dio.dart';

import '../network/api_client.dart';

abstract interface class PushInstallationRegistry {
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken});

  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  });
}

class PushRegistrationApi implements PushInstallationRegistry {
  const PushRegistrationApi(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {
    final data = {'fid': fid, 'platform': 'ANDROID'};
    if (cancelToken == null) {
      await _apiClient.putJson('/api/v1/push/installations/current', data);
      return;
    }
    await _apiClient.putJsonCancellable(
      '/api/v1/push/installations/current',
      data,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {
    await _apiClient.deleteJsonWithData(
      '/api/v1/push/installations/current',
      {'fid': fid, 'platform': 'ANDROID'},
      cancelToken: cancelToken,
      bearerToken: bearerToken,
    );
  }
}
