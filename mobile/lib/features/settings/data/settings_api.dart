import '../../../core/network/api_client.dart';
import '../models/user_settings.dart';

class SettingsApi {
  const SettingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<UserSettings> getSettings() async {
    final json = await _apiClient.getJson('/users/me/settings');
    return UserSettings.fromJson(json);
  }

  Future<UserSettings> updateSettings(UserSettings settings) async {
    final json = await _apiClient.patchJson(
      '/users/me/settings',
      settings.toUpdateJson(),
    );
    return UserSettings.fromJson(json);
  }
}
