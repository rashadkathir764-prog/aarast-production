import '../network/api_client.dart';

abstract interface class PushInstallationRegistry {
  Future<void> registerAndroid(String fid);

  Future<void> unregisterAndroid(String fid);
}

class PushRegistrationApi implements PushInstallationRegistry {
  const PushRegistrationApi(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> registerAndroid(String fid) async {
    await _apiClient.putJson('/api/v1/push/installations/current', {
      'fid': fid,
      'platform': 'ANDROID',
    });
  }

  @override
  Future<void> unregisterAndroid(String fid) async {
    await _apiClient.deleteJsonWithData('/api/v1/push/installations/current', {
      'fid': fid,
      'platform': 'ANDROID',
    });
  }
}
