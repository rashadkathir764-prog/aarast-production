import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D85: the invitation card is the plan's, so a card saved with no
/// connection waits on the phone under its plan, like the guests do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a card saved with no connection is kept and queued under its plan',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final client = _NoConnectionClient();
      final offline = OfflineSyncService(database: database, apiClient: client);
      await offline.refreshStatus();
      final api = GuestsApi(client, offline: offline);

      final card = await api.setInvitationCard('plan-account-1', {
        'hostLine': 'أبو محمد الحمدي',
        'mapUrl': 'https://maps.app.goo.gl/abc',
      });

      expect(card.hostLine, 'أبو محمد الحمدي');
      expect(card.mapUrl, 'https://maps.app.goo.gl/abc');
      final pending = await database.pendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.single.entityType, 'guest_invitation_card');
      expect(pending.single.planId, 'plan-account-1');
      // The phone's copy is what the screen reads back while it waits.
      final kept = await api.getInvitationCard('plan-account-1');
      expect(kept.hostLine, 'أبو محمد الحمدي');
    },
  );
}

class _NoConnectionClient extends ApiClient {
  _NoConnectionClient() : super(tokenProvider: () async => null);

  static const _offline = ApiException(
    aarastBackendConnectionErrorMessage,
    isNetworkFailure: true,
  );

  @override
  Future<Map<String, dynamic>> getJson(String path) async => throw _offline;

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async => throw _offline;
}
