import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/account_deletion_impact.dart';
import '../models/preference_coverage.dart';
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
  static const _scheduleKey = 'reminder-schedule';

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
    final read = await _reads.cachedBlob(_settingsKey);
    final cached = read ?? const <String, dynamic>{};
    final whole = settings.toUpdateJson();
    // RA-MO-288: one switch saved all three as the phone had read them:
    // the provider's «رسائل العملاء» switch took back a reminder switch
    // changed from the couple's settings on another phone, and the
    // reverse. A save sends the switches that differ from the phone's
    // copy (what it last read, or last saved); the server keeps the rest.
    final payload = read == null
        ? whole
        : <String, dynamic>{
            for (final entry in whole.entries)
              if (cached[entry.key] != entry.value) entry.key: entry.value,
          };
    if (payload.isEmpty) return settings;
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

  /// The server's reminder table and what each switch covers, for the
  /// settings' «يشمل» and «متى يصلك» lines; a part the phone cannot read
  /// whole (another version) is null.
  Future<NotificationSchedule> getNotificationSchedule() async {
    return NotificationSchedule.fromResponse(
      await _reads.blob(
        '/api/v1/notifications/schedule',
        metaKey: _scheduleKey,
      ),
    );
  }

  /// The phone's copy of the answer, or null before the first one.
  Future<NotificationSchedule?> cachedNotificationSchedule() async {
    final json = await _reads.cachedBlob(_scheduleKey);
    return json == null ? null : NotificationSchedule.fromResponse(json);
  }

  /// D63 (w05): what deleting the account takes with it.
  Future<AccountDeletionImpact> deletionImpact() async {
    return AccountDeletionImpact.fromJson(
      await _writes.serverOnly(
        reason: 'حذف الحساب يحتاج النت.',
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
      reason: 'تجهيز الرابط يحتاج النت.',
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
