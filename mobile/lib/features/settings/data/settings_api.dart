import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/account_deletion_impact.dart';
import '../models/user_settings.dart';

/// The account's settings and privacy.
///
/// D85: settings and the privacy answer are the phone's copy when the
/// server is out of reach, and a change is kept on the phone and sent when
/// the server answers. The deletion impact and the data export are the
/// server's say and wait for it.
class SettingsApi {
  SettingsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  static const _settingsKey = 'user-settings';
  static const _privacyKey = 'user-privacy';

  Future<UserSettings> getSettings() async {
    return UserSettings.fromJson(
      await _reads.blob('/api/v1/users/me/settings', metaKey: _settingsKey),
    );
  }

  /// The phone's copy alone, or null before the first answer.
  Future<UserSettings?> cachedSettings() async {
    final json = await _reads.cachedBlob(_settingsKey);
    return json == null ? null : UserSettings.fromJson(json);
  }

  Future<UserSettings> updateSettings(UserSettings settings) async {
    final cached = await _reads.cachedBlob(_settingsKey) ?? const {};
    final payload = settings.toUpdateJson();
    final json = await _writes.queued(
      entityType: 'user_settings',
      operation: 'update',
      method: 'PATCH',
      endpoint: '/api/v1/users/me/settings',
      payload: payload,
      metaKey: _settingsKey,
      localJson: {...cached, ...payload},
      localEntityId: 'user-settings',
      replacePendingForEntity: true,
    );
    return UserSettings.fromJson(json);
  }

  /// D63 (w05): what deleting the account takes with it.
  Future<AccountDeletionImpact> deletionImpact() async {
    return AccountDeletionImpact.fromJson(
      await _writes.serverOnly(
        reason: 'الحساب يُحذف عند الخادم، فنسأله قبلها.',
        method: 'GET',
        path: '/api/v1/users/me/deletion/impact',
      ),
    );
  }

  /// D63 (w40): whether the account's reviews show its first name only.
  Future<bool> reviewFirstNameOnly() async {
    final json = await _reads.blob(
      '/api/v1/users/me/privacy',
      metaKey: _privacyKey,
    );
    return json['reviewFirstNameOnly'] == true;
  }

  Future<bool> setReviewFirstNameOnly(bool value) async {
    final json = await _writes.queued(
      entityType: 'user_privacy',
      operation: 'update',
      method: 'PATCH',
      endpoint: '/api/v1/users/me/privacy',
      payload: {'reviewFirstNameOnly': value},
      metaKey: _privacyKey,
      localJson: {'reviewFirstNameOnly': value},
      localEntityId: 'user-privacy',
      replacePendingForEntity: true,
    );
    return json['reviewFirstNameOnly'] == true;
  }

  /// D63 (w40 «نزّل بياناتي»): a one-time link to the account's own data,
  /// on the API host; it works once, for fifteen minutes.
  Future<Uri> createDataExport() async {
    final json = await _writes.serverOnly(
      reason: 'الرابط يصدره الخادم لمدة قصيرة.',
      method: 'POST',
      path: '/api/v1/users/me/exports',
    );
    final path = json['downloadPath']?.toString() ?? '';
    if (!path.startsWith('/api/v1/data-exports/')) {
      throw const FormatException('Data export response has no link');
    }
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }
}
