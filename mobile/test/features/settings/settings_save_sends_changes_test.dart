import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-288 (batch 9): one switch saved all three notification switches as
// the phone had read them. The provider's «رسائل العملاء» switch took back
// a reminder switch changed from another phone, and the reverse. A save
// sends the switches that differ from the phone's copy.
void main() {
  test('one switch changed sends that switch, and nothing else', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _Client();
    final offline = OfflineSyncService(
      database: JsonLocalDatabase(await SharedPreferences.getInstance()),
      apiClient: client,
    );
    await offline.ensureCacheOwner('user-1');
    final api = SettingsApi(client, offline: offline);

    final read = await api.getSettings();
    expect(read.providerMessagesEnabled, isTrue);

    await api.updateSettings(read.copyWith(providerMessagesEnabled: false));

    expect(client.sent.single, {'providerMessagesEnabled': false});
  });

  test('a save that changed nothing asks the server for nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _Client();
    final offline = OfflineSyncService(
      database: JsonLocalDatabase(await SharedPreferences.getInstance()),
      apiClient: client,
    );
    await offline.ensureCacheOwner('user-1');
    final api = SettingsApi(client, offline: offline);

    final read = await api.getSettings();
    await api.updateSettings(read);

    expect(client.sent, isEmpty);
  });
}

class _Client extends ApiClient {
  _Client() : super(tokenProvider: () async => 'token');

  final sent = <Map<String, dynamic>>[];

  static const _settings = <String, dynamic>{
    'id': 'settings-1',
    'userId': 'user-1',
    'pushEnabled': true,
    'taskRemindersEnabled': true,
    'paymentRemindersEnabled': true,
    'providerMessagesEnabled': true,
  };

  @override
  Future<Map<String, dynamic>> getJson(String path) async => _settings;

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async {
    sent.add(data);
    return {..._settings, ...data};
  }
}
