import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/account_deletion_impact.dart';
import '../models/user_settings.dart';

class SettingsApi {
  const SettingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<UserSettings> getSettings() async {
    final json = await _apiClient.getJson('/api/v1/users/me/settings');
    return UserSettings.fromJson(json);
  }

  Future<UserSettings> updateSettings(UserSettings settings) async {
    final json = await _apiClient.patchJson(
      '/api/v1/users/me/settings',
      settings.toUpdateJson(),
    );
    return UserSettings.fromJson(json);
  }

  /// D63 (w05): what deleting the account takes with it.
  Future<AccountDeletionImpact> deletionImpact() async {
    return AccountDeletionImpact.fromJson(
      await _apiClient.getJson('/api/v1/users/me/deletion/impact'),
    );
  }

  /// D63 (w40): whether the account's reviews show its first name only.
  Future<bool> reviewFirstNameOnly() async {
    final json = await _apiClient.getJson('/api/v1/users/me/privacy');
    return json['reviewFirstNameOnly'] == true;
  }

  Future<bool> setReviewFirstNameOnly(bool value) async {
    final json = await _apiClient.patchJson('/api/v1/users/me/privacy', {
      'reviewFirstNameOnly': value,
    });
    return json['reviewFirstNameOnly'] == true;
  }

  /// D63 (w40 «نزّل بياناتي»): a one-time link to the account's own data,
  /// on the API host; it works once, for fifteen minutes.
  Future<Uri> createDataExport() async {
    final json = await _apiClient.postJson('/api/v1/users/me/exports', {});
    final path = json['downloadPath']?.toString() ?? '';
    if (!path.startsWith('/api/v1/data-exports/')) {
      throw const FormatException('Data export response has no link');
    }
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }
}
