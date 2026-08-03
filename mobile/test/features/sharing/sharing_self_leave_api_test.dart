import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'self leave sends the DELETE route with its caller-owned request id',
    () async {
      final client = _RecordingApiClient();
      final api = SharingApi(client);

      await api.leaveCurrentPlan(
        weddingPlanId: 'plan-42',
        expectedMemberId: 'member-tenure-7',
        expectedAuthorityVersion: 7,
        clientRequestId: 'f1a2516d-c978-43a1-864d-37688327741d',
      );

      expect(client.path, '/api/v1/wedding-plans/plan-42/members/me');
      expect(client.method, 'DELETE');
      expect(client.payload, {
        'expectedMemberId': 'member-tenure-7',
        'expectedAuthorityVersion': 7,
      });
      expect(client.clientRequestId, 'f1a2516d-c978-43a1-864d-37688327741d');
    },
  );
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(tokenProvider: () async => 'token');

  String? path;
  String? method;
  Map<String, dynamic>? payload;
  String? clientRequestId;

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async {
    this.path = path;
    this.method = method;
    payload = data;
    this.clientRequestId = clientRequestId;
    return const {};
  }
}
